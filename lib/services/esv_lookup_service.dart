import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/book_name_variants.dart' show bookDisplayNames, bookNameToUsfm;
import 'bible_lookup_service.dart' show LookupException, VerseLookupResult;
import 'net_security.dart';

/// Fetches verse text from api.esv.org (Crossway's ESV API).
///
/// SSRF: only api.esv.org contacted; scheme+host validated per request.
/// Privacy: no verse reference, API key, or other PII written to any log.
/// Crossway's terms cap local ESV storage at 500 verses (enforced by callers,
/// not this service — see `DatabaseHelper.insertEsvVerse`).
class EsvLookupService {
  EsvLookupService({http.Client? client, String apiKey = const String.fromEnvironment('ESV_API_KEY')})
      : _client = client ?? http.Client(),
        _apiKey = apiKey;

  static const _allowedHost = 'api.esv.org';
  static const _baseUrl = 'https://api.esv.org/v3/passage/text/';

  // LRU-bounded per-session cache. Bounded by screen lifetime (disposed with screen).
  static const _maxCacheSize = 50;
  final Map<String, VerseLookupResult> _cache = {};

  final http.Client _client;
  final String _apiKey;

  /// True when this instance was constructed with a non-empty API key.
  /// Callers should check this before rendering the ESV option in the UI.
  bool get isAvailable => _apiKey.isNotEmpty;

  static final _referencePattern = RegExp(r'^[A-Za-z0-9 :,\-]{1,100}$');
  static final _refParsePattern = RegExp(r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?\s*$');

  Future<VerseLookupResult> lookup(String reference) async {
    if (_apiKey.isEmpty) {
      throw StateError('ESV API key is not configured.');
    }
    if (!_referencePattern.hasMatch(reference)) {
      throw ArgumentError('Invalid reference format.');
    }

    final cacheKey = '$reference|ESV';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final canonicalRef = _canonicalReference(reference);
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': canonicalRef,
      'include-passage-references': 'false',
      'include-verse-numbers': 'false',
      'include-footnotes': 'false',
      'include-headings': 'false',
      'include-short-copyright': 'false',
    });
    assertAllowedHttpsHost(uri, {_allowedHost});

    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Token $_apiKey', 'Accept': 'application/json'})
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

    final result = _parse(response.body, reference);
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;
    return result;
  }

  String _canonicalReference(String reference) {
    final m = _refParsePattern.firstMatch(reference.trim());
    if (m == null) {
      throw const LookupException('Use format "Book Chapter:Verse" e.g. "Romans 8:28".');
    }
    final bookName = m.group(1)!.trim();
    final usfm = bookNameToUsfm(bookName);
    if (usfm == null) {
      throw const LookupException('Unknown book name. Check spelling and try again.');
    }
    final displayName = bookDisplayNames[usfm]!;
    final chapter = m.group(2)!;
    final startVerse = m.group(3)!;
    final endVerse = m.group(4);
    final verseRange = endVerse != null ? '$startVerse-$endVerse' : startVerse;
    return '$displayName $chapter:$verseRange';
  }

  VerseLookupResult _parse(String body, String reference) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        throw const LookupException('Unexpected response format.');
      }
      final passages = json['passages'] as List<dynamic>?;
      if (passages == null || passages.isEmpty) {
        throw const LookupException('No verse text found for that reference.');
      }
      final text = (passages.first as String?)?.trim() ?? '';
      if (text.isEmpty) {
        throw const LookupException('No verse text found for that reference.');
      }
      return VerseLookupResult(reference: reference, text: text, translation: 'ESV');
    } on LookupException {
      rethrow;
    } catch (_) {
      throw const LookupException('Could not read response. Try again.');
    }
  }

  void dispose() => _client.close();
}
