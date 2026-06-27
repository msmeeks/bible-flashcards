import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/book_name_variants.dart' show bookNameToUsfm;
import 'net_security.dart';

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
    assertAllowedHttpsHost(uri, {_allowedHost});

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

  static String? _bookToUsfm(String name) => bookNameToUsfm(name);

  void dispose() => _client.close();
}

class LookupException implements Exception {
  const LookupException(this.message);
  final String message;

  @override
  String toString() => message;
}
