import 'dart:math';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/settings.dart';
import '../models/verse.dart';

class VerseProvider extends ChangeNotifier {
  final DatabaseHelper _db;

  VerseProvider(this._db);

  List<Verse> _verses = [];
  Map<String, String> _packNames = {};
  bool _isLoading = false;
  String? _error;

  List<Verse> get memorizedVerses =>
      _verses.where((v) => v.isMemorized).toList();

  List<Verse> get availableVerses =>
      _verses.where((v) => !v.isMemorized).toList();

  Verse? get verseOfWeek => _verses.where((v) => v.isVerseOfWeek).firstOrNull;

  int get esvVerseCount => _verses.where((v) => v.translation == 'ESV').length;

  Map<String, String> get packNames => _packNames;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVerses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _verses = await _db.getVerses();
      _packNames = await _db.getPackNames();
    } catch (e) {
      _error = 'Failed to load verses: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setVerseOfWeek(String id) async {
    // Clear existing verse-of-week, then set the new one.
    final updates = <Future<void>>[];
    for (final verse in _verses.where((v) => v.isVerseOfWeek)) {
      final updated = verse.copyWith(isVerseOfWeek: false);
      updates.add(_db.updateVerse(updated));
    }
    await Future.wait(updates);

    final target = _verses.indexWhere((v) => v.id == id);
    if (target == -1) return;
    final updated = _verses[target].copyWith(isVerseOfWeek: true);
    await _db.updateVerse(updated);

    await loadVerses();
  }

  Future<void> markMemorized(String id) async {
    final index = _verses.indexWhere((v) => v.id == id);
    if (index == -1) return;
    final updated = _verses[index].copyWith(
      isMemorized: true,
      memorizedAt: DateTime.now(),
    );
    await _db.updateVerse(updated);
    await loadVerses();
  }

  Future<void> addCustomVerse(Verse verse) async {
    if (verse.translation == 'ESV') {
      await _db.insertEsvVerse(verse);
    } else {
      await _db.insertVerse(verse);
    }
    await loadVerses();
  }

  Future<void> unmarkMemorized(String id) async {
    final index = _verses.indexWhere((v) => v.id == id);
    if (index == -1) return;
    final updated =
        _verses[index].copyWith(isMemorized: false, clearMemorizedAt: true);
    await _db.unmarkMemorizedVerse(updated);
    await loadVerses();
  }

  /// Returns up to [count] randomly chosen memorized verses.
  ///
  /// When [includeVerseOfWeek] is true and the verse-of-week is memorized,
  /// it always occupies one of the returned slots. When false, the
  /// verse-of-week is excluded from the result entirely.
  List<Verse> getRandomMemorizedVerses(
    int count, {
    bool includeVerseOfWeek = false,
  }) {
    final rng = Random();
    final vow = verseOfWeek;
    final vowEligible = includeVerseOfWeek && vow != null && vow.isMemorized;

    final pool = includeVerseOfWeek
        ? memorizedVerses.toList()
        : memorizedVerses.where((v) => !v.isVerseOfWeek).toList();

    if (count == 0) return [];

    pool.shuffle(rng);
    final result =
        (pool.length <= count ? pool : pool.sublist(0, count)).toList();

    if (vowEligible && !result.any((v) => v.id == vow.id)) {
      result[rng.nextInt(result.length)] = vow;
    }

    return result;
  }

  /// Returns the verse that should become the new verse of the week, or
  /// null if no advance should happen right now. Pure decision logic, kept
  /// separate from the DB write in [autoAdvanceVerseOfWeekIfNeeded] so it can
  /// be unit tested without a real database.
  @visibleForTesting
  Verse? pickVerseForAutoAdvance(AppSettings settings, DateTime now) {
    if (!settings.autoAdvanceVerseOfWeek) return null;
    if (now.weekday != DateTime.sunday) return null;
    if (settings.lastVerseAdvanceDate != null &&
        _isSameIsoWeek(settings.lastVerseAdvanceDate!, now)) {
      return null;
    }
    final candidates = _verses.where((v) => !v.isVerseOfWeek).toList();
    if (candidates.isEmpty) return null;
    return candidates[Random().nextInt(candidates.length)];
  }

  bool _isSameIsoWeek(DateTime a, DateTime b) {
    final aMonday = a.subtract(Duration(days: a.weekday - 1));
    final bMonday = b.subtract(Duration(days: b.weekday - 1));
    return aMonday.year == bMonday.year &&
        aMonday.month == bMonday.month &&
        aMonday.day == bMonday.day;
  }

  /// Advances the verse of the week when [settings] has auto-advance
  /// enabled, today is Sunday, and this ISO week hasn't already advanced.
  /// Calls [onUpdate] with the persisted advance date so the caller can
  /// write it back through [SettingsProvider].
  Future<void> autoAdvanceVerseOfWeekIfNeeded(
    AppSettings settings,
    void Function(AppSettings) onUpdate, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final picked = pickVerseForAutoAdvance(settings, today);
    if (picked == null) return;
    await setVerseOfWeek(picked.id);
    onUpdate(settings.copyWith(lastVerseAdvanceDate: today));
  }

  @visibleForTesting
  void debugSetVerses(List<Verse> verses) {
    assert(() {
      _verses = verses;
      return true;
    }(), 'debugSetVerses is only available in debug/test builds');
  }
}
