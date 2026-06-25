import 'dart:math';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
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
    await _db.insertVerse(verse);
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

    var pool = memorizedVerses.toList();
    if (!includeVerseOfWeek) {
      pool = pool.where((v) => !v.isVerseOfWeek).toList();
    }

    pool.shuffle(rng);
    final selected = pool.length <= count ? pool : pool.sublist(0, count);

    if (vowEligible && !selected.any((v) => v.id == vow.id)) {
      if (selected.isEmpty) {
        selected.add(vow);
      } else {
        selected[rng.nextInt(selected.length)] = vow;
      }
    }

    return selected;
  }

  @visibleForTesting
  void debugSetVerses(List<Verse> verses) {
    _verses = verses;
  }
}
