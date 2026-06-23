import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class VerseLookupResult {
  const VerseLookupResult({
    required this.reference,
    required this.text,
    required this.translation,
  });

  final String reference;
  final String text;
  final String translation;
}

class _VerseRef {
  const _VerseRef({
    required this.usfm,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
  });
  final String usfm;
  final int chapter;
  final int startVerse;
  final int endVerse;
}

/// Fetches verse text from bible.helloao.org (/{translation}/{bookUsfm}/{chapter}.json).
///
/// SSRF: only bible.helloao.org contacted; scheme+host validated per request.
/// HTTPS only: cleartext blocked at network_security_config.xml and enforced here.
/// Privacy: no verse reference or PII written to any log.
class BibleLookupService {
  BibleLookupService({http.Client? client}) : _client = client ?? http.Client();

  static const _allowedHost = 'bible.helloao.org';
  static const _baseUrl = 'https://bible.helloao.org/api';

  // Translation label → API translation ID.
  // IDs verified against https://bible.helloao.org/api/available_translations.json
  static const _translationIds = <String, String>{
    'BSB': 'BSB',       // Berean Standard Bible (modern, freely available)
    'KJV': 'eng_kjv',  // King James Version
    'WEB': 'ENGWEBP',  // World English Bible (modern, freely available)
  };

  // LRU-bounded per-session cache. Bounded by screen lifetime (disposed with screen).
  static const _maxCacheSize = 50;
  final Map<String, VerseLookupResult> _cache = {};

  final http.Client _client;

  static final _referencePattern = RegExp(r'^[A-Za-z0-9 :,\-]{1,100}$');
  static final _refParsePattern = RegExp(r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?\s*$');

  Future<VerseLookupResult> lookup(String reference, String translation) async {
    if (!_referencePattern.hasMatch(reference)) {
      throw ArgumentError('Invalid reference format.');
    }
    final translationId = _translationIds[translation];
    if (translationId == null) {
      throw ArgumentError('Unsupported translation: $translation');
    }

    final cacheKey = '$reference|$translation';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final ref = _parseRef(reference);
    final uri = Uri.parse('$_baseUrl/$translationId/${ref.usfm}/${ref.chapter}.json');
    _assertHttps(uri);

    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const LookupException('Request timed out. Check your connection.');
    } catch (_) {
      throw const LookupException('Network error. Check your connection.');
    }

    if (response.statusCode == 404) {
      throw const LookupException('Verse not found. Check the reference and try again.');
    }
    if (response.statusCode != 200) {
      throw LookupException('Lookup failed (${response.statusCode}).');
    }

    final result = _parse(response.body, reference, translation, ref);
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;
    return result;
  }

  _VerseRef _parseRef(String reference) {
    final m = _refParsePattern.firstMatch(reference.trim());
    if (m == null) {
      throw const LookupException('Use format "Book Chapter:Verse" e.g. "Romans 8:28".');
    }
    final bookName = m.group(1)!.trim();
    final chapter = int.parse(m.group(2)!);
    final startVerse = int.parse(m.group(3)!);
    final endVerse = m.group(4) != null ? int.parse(m.group(4)!) : startVerse;
    final usfm = _bookToUsfm(bookName);
    if (usfm == null) {
      throw const LookupException('Unknown book name. Check spelling and try again.');
    }
    return _VerseRef(usfm: usfm, chapter: chapter, startVerse: startVerse, endVerse: endVerse);
  }

  void _assertHttps(Uri uri) {
    if (uri.scheme != 'https') throw StateError('Non-HTTPS URL rejected.');
    if (uri.host != _allowedHost) throw StateError('Disallowed host: ${uri.host}');
  }

  VerseLookupResult _parse(
    String body,
    String reference,
    String translation,
    _VerseRef ref,
  ) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        throw const LookupException('Unexpected response format.');
      }
      final verses = json['verses'] as List<dynamic>?;
      if (verses == null || verses.isEmpty) {
        throw const LookupException('No verse text found for that reference.');
      }
      final text = verses
          .whereType<Map<String, dynamic>>()
          .where((v) {
            final n = v['verse'] as int?;
            return n != null && n >= ref.startVerse && n <= ref.endVerse;
          })
          .map((v) => (v['text'] as String?)?.trim() ?? '')
          .where((t) => t.isNotEmpty)
          .join(' ');
      if (text.isEmpty) {
        throw const LookupException('No verse text found for that reference.');
      }
      return VerseLookupResult(reference: reference, text: text, translation: translation);
    } on LookupException {
      rethrow;
    } catch (_) {
      throw const LookupException('Could not read response. Try again.');
    }
  }

  static String? _bookToUsfm(String name) {
    final key = name.toLowerCase().replaceAll(RegExp(r'[\s\.]+'), '');
    return _bookMap[key];
  }

  // Book name variants (lowercase, spaces/dots stripped) → USFM code.
  static const _bookMap = <String, String>{
    // Old Testament
    'genesis': 'GEN', 'gen': 'GEN',
    'exodus': 'EXO', 'exod': 'EXO', 'exo': 'EXO',
    'leviticus': 'LEV', 'lev': 'LEV',
    'numbers': 'NUM', 'num': 'NUM',
    'deuteronomy': 'DEU', 'deut': 'DEU', 'deu': 'DEU',
    'joshua': 'JOS', 'josh': 'JOS', 'jos': 'JOS',
    'judges': 'JDG', 'judg': 'JDG', 'jdg': 'JDG',
    'ruth': 'RUT', 'rut': 'RUT',
    '1samuel': '1SA', '1sam': '1SA', '1sa': '1SA',
    '2samuel': '2SA', '2sam': '2SA', '2sa': '2SA',
    '1kings': '1KI', '1kgs': '1KI', '1ki': '1KI',
    '2kings': '2KI', '2kgs': '2KI', '2ki': '2KI',
    '1chronicles': '1CH', '1chron': '1CH', '1chr': '1CH', '1ch': '1CH',
    '2chronicles': '2CH', '2chron': '2CH', '2chr': '2CH', '2ch': '2CH',
    'ezra': 'EZR', 'ezr': 'EZR',
    'nehemiah': 'NEH', 'neh': 'NEH',
    'esther': 'EST', 'esth': 'EST', 'est': 'EST',
    'job': 'JOB',
    'psalm': 'PSA', 'psalms': 'PSA', 'psa': 'PSA', 'ps': 'PSA',
    'proverbs': 'PRO', 'prov': 'PRO', 'pro': 'PRO',
    'ecclesiastes': 'ECC', 'eccl': 'ECC', 'ecc': 'ECC',
    'songofsolomon': 'SNG', 'songofsongs': 'SNG', 'song': 'SNG', 'sos': 'SNG', 'sng': 'SNG',
    'isaiah': 'ISA', 'isa': 'ISA',
    'jeremiah': 'JER', 'jer': 'JER',
    'lamentations': 'LAM', 'lam': 'LAM',
    'ezekiel': 'EZK', 'ezek': 'EZK', 'eze': 'EZK', 'ezk': 'EZK',
    'daniel': 'DAN', 'dan': 'DAN',
    'hosea': 'HOS', 'hos': 'HOS',
    'joel': 'JOL', 'joe': 'JOL', 'jol': 'JOL',
    'amos': 'AMO', 'amo': 'AMO',
    'obadiah': 'OBA', 'obad': 'OBA', 'oba': 'OBA',
    'jonah': 'JON', 'jon': 'JON',
    'micah': 'MIC', 'mic': 'MIC',
    'nahum': 'NAH', 'nah': 'NAH',
    'habakkuk': 'HAB', 'hab': 'HAB',
    'zephaniah': 'ZEP', 'zeph': 'ZEP', 'zep': 'ZEP',
    'haggai': 'HAG', 'hag': 'HAG',
    'zechariah': 'ZEC', 'zech': 'ZEC', 'zec': 'ZEC',
    'malachi': 'MAL', 'mal': 'MAL',
    // New Testament
    'matthew': 'MAT', 'matt': 'MAT', 'mat': 'MAT',
    'mark': 'MRK', 'mar': 'MRK', 'mrk': 'MRK',
    'luke': 'LUK', 'luk': 'LUK',
    'john': 'JHN', 'joh': 'JHN', 'jhn': 'JHN',
    'acts': 'ACT', 'act': 'ACT',
    'romans': 'ROM', 'rom': 'ROM',
    '1corinthians': '1CO', '1cor': '1CO', '1co': '1CO',
    '2corinthians': '2CO', '2cor': '2CO', '2co': '2CO',
    'galatians': 'GAL', 'gal': 'GAL',
    'ephesians': 'EPH', 'eph': 'EPH',
    'philippians': 'PHP', 'phil': 'PHP', 'php': 'PHP',
    'colossians': 'COL', 'col': 'COL',
    '1thessalonians': '1TH', '1thess': '1TH', '1th': '1TH',
    '2thessalonians': '2TH', '2thess': '2TH', '2th': '2TH',
    '1timothy': '1TI', '1tim': '1TI', '1ti': '1TI',
    '2timothy': '2TI', '2tim': '2TI', '2ti': '2TI',
    'titus': 'TIT', 'tit': 'TIT',
    'philemon': 'PHM', 'phlm': 'PHM', 'phm': 'PHM',
    'hebrews': 'HEB', 'heb': 'HEB',
    'james': 'JAS', 'jas': 'JAS',
    '1peter': '1PE', '1pet': '1PE', '1pe': '1PE',
    '2peter': '2PE', '2pet': '2PE', '2pe': '2PE',
    '1john': '1JN', '1jn': '1JN',
    '2john': '2JN', '2jn': '2JN',
    '3john': '3JN', '3jn': '3JN',
    'jude': 'JUD', 'jud': 'JUD',
    'revelation': 'REV', 'rev': 'REV', 'apoc': 'REV',
  };

  void dispose() => _client.close();
}

class LookupException implements Exception {
  const LookupException(this.message);
  final String message;

  @override
  String toString() => message;
}
