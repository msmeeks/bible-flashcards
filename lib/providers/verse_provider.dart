import 'dart:math';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/settings.dart';
import '../models/verse.dart';
import '../models/verse_pack.dart';

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

  /// The pack a verse is shown under: its own pack if that still exists,
  /// otherwise My Verses (hand-added verses, or a pack that's gone).
  String resolvePackId(String packId) =>
      _packNames.containsKey(packId) ? packId : VersePack.myVersesId;

  String packNameFor(String packId) =>
      _packNames[resolvePackId(packId)] ?? VersePack.myVersesName;

  /// Packs a verse can belong to: My Verses first, then built-in packs, then
  /// the user's own packs alphabetically.
  List<String> get packIds {
    final builtIn = _packNames.keys
        .where(
            (id) => !VersePack.isUserPackId(id) && id != VersePack.myVersesId)
        .toList();
    final user = _packNames.keys.where(VersePack.isUserPackId).toList()
      ..sort((a, b) =>
          _packNames[a]!.toLowerCase().compareTo(_packNames[b]!.toLowerCase()));
    return [VersePack.myVersesId, ...builtIn, ...user];
  }

  static const maxPackNameLength = 40;

  /// Returns an error message for an unusable pack name, or null if it's fine.
  /// Pass [renaming] with a pack's id to let it keep its current name.
  String? validatePackName(String name, {String? renaming}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a pack name';
    if (trimmed.length > maxPackNameLength) {
      return 'Pack name must be $maxPackNameLength characters or fewer';
    }
    final key = trimmed.toLowerCase();
    final taken = packIds.any(
      (id) => id != renaming && packNameFor(id).toLowerCase() == key,
    );
    return taken ? 'You already have a pack with that name' : null;
  }

  /// Creates a user pack and returns its id. Throws [ArgumentError] if
  /// [validatePackName] rejects [name].
  Future<String> createPack(String name) async {
    final error = validatePackName(name);
    if (error != null) throw ArgumentError(error);
    final id =
        '${VersePack.userPackPrefix}${DateTime.now().microsecondsSinceEpoch}';
    await _db.insertPack(id, name.trim());
    await loadVerses();
    return id;
  }

  Future<void> renamePack(String id, String name) async {
    _requireUserPack(id);
    final error = validatePackName(name, renaming: id);
    if (error != null) throw ArgumentError(error);
    await _db.renamePack(id, name.trim());
    await loadVerses();
  }

  /// Deletes a user pack; its verses move to My Verses.
  Future<void> deletePack(String id) async {
    _requireUserPack(id);
    await _db.deletePack(id);
    await loadVerses();
  }

  Future<void> moveVerseToPack(String verseId, String packId) async {
    if (!packIds.contains(packId)) {
      throw ArgumentError.value(packId, 'packId', 'Unknown pack');
    }
    final verse = _verses.where((v) => v.id == verseId).firstOrNull;
    if (verse == null) return;
    await _db.updateVerse(verse.copyWith(packId: packId));
    await loadVerses();
  }

  void _requireUserPack(String id) {
    if (!VersePack.isUserPackId(id) || !_packNames.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'Not one of your packs');
    }
  }

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

  @visibleForTesting
  void debugSetLoading(bool value) {
    assert(() {
      _isLoading = value;
      return true;
    }(), 'debugSetLoading is only available in debug/test builds');
    notifyListeners();
  }
}
