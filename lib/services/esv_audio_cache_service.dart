import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches and caches Crossway ESV audio recordings from api.esv.org.
///
/// Two-request pattern: the Authorization header is sent only to api.esv.org
/// to resolve the redirect; the actual MP3 fetch from the CDN target carries
/// no auth header, so a compromised/misconfigured CDN can never see the key.
///
/// Reuses the `esv_lookup_consent_v1` consent flag — by the time a user has
/// ESV verses saved, they have already consented to send Bible references to
/// Crossway via text lookup, so audio playback (same reference, same
/// recipient) does not require a separate consent prompt. See PRIVACY.md.
class EsvAudioCacheService {
  EsvAudioCacheService({
    http.Client? client,
    String apiKey = const String.fromEnvironment('ESV_API_KEY'),
    Directory? cacheDir,
    int maxCachedFiles = 250,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey,
        _cacheDir = cacheDir,
        _maxCachedFiles = maxCachedFiles;

  static const _consentPrefKey = 'esv_lookup_consent_v1';
  static const _audioBaseUrl = 'https://api.esv.org/v3/passage/audio/';
  static const _allowedAudioHosts = {'audio.esv.org'};

  final http.Client _client;
  final String _apiKey;
  final Directory? _cacheDir;
  final int _maxCachedFiles;

  final Map<String, Future<String>> _inFlight = {};

  bool get isAvailable => _apiKey.isNotEmpty;

  Future<String> getAudioPath(String reference) {
    return _inFlight.putIfAbsent(reference, () async {
      try {
        return await _fetchAndCache(reference);
      } finally {
        _inFlight.remove(reference);
      }
    });
  }

  Future<String> _fetchAndCache(String reference) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_consentPrefKey) != true) {
      throw const EsvAudioConsentRequired();
    }

    final audioDir = await _resolveAudioDir();
    final file = File(path.join(audioDir.path, _cacheKey(reference)));
    if (await file.exists()) return file.path;

    final cdnUri = await _resolveCdnUri(reference);
    _assertAllowedAudioHost(cdnUri);

    final audioResponse = await _client.get(cdnUri).timeout(const Duration(seconds: 30));
    if (audioResponse.statusCode != 200) {
      throw EsvAudioException('Audio fetch failed (${audioResponse.statusCode}).');
    }

    await _evictIfNeeded(audioDir);
    await file.writeAsBytes(audioResponse.bodyBytes);
    return file.path;
  }

  Future<Uri> _resolveCdnUri(String reference) async {
    final resolveUri = Uri.parse(_audioBaseUrl).replace(queryParameters: {'q': reference});
    if (resolveUri.scheme != 'https' || resolveUri.host != 'api.esv.org') {
      throw EsvAudioException('Disallowed host: ${resolveUri.host}');
    }

    final resolveRequest = http.Request('GET', resolveUri)
      ..headers['Authorization'] = 'Token $_apiKey'
      ..followRedirects = false;
    http.Response resolveResponse;
    try {
      final resolveStreamed = await _client.send(resolveRequest);
      resolveResponse = await http.Response.fromStream(resolveStreamed);
    } catch (e) {
      if (e is EsvAudioException) rethrow;
      throw EsvAudioException('Network error resolving audio redirect: $e');
    }

    if (resolveResponse.statusCode != 301 && resolveResponse.statusCode != 302) {
      throw EsvAudioException('Unexpected status: ${resolveResponse.statusCode}');
    }
    final location = resolveResponse.headers['location'];
    if (location == null) throw const EsvAudioException('No redirect location.');
    return Uri.parse(location);
  }

  void _assertAllowedAudioHost(Uri uri) {
    if (uri.scheme != 'https') throw EsvAudioException('Non-HTTPS redirect: ${uri.scheme}');
    if (!_allowedAudioHosts.contains(uri.host)) {
      throw EsvAudioException('Unexpected audio host: ${uri.host}');
    }
  }

  Future<Directory> _resolveAudioDir() async {
    final base = _cacheDir ?? await getApplicationCacheDirectory();
    final audioDir = Directory(path.join(base.path, 'esv_audio'));
    await audioDir.create(recursive: true);
    return audioDir;
  }

  Future<void> _evictIfNeeded(Directory dir) async {
    final entries = await dir.list().toList();
    final files = entries.whereType<File>().toList();
    if (files.length < _maxCachedFiles) return;
    files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in files.take(files.length - _maxCachedFiles + 1)) {
      await f.delete();
    }
  }

  String _cacheKey(String reference) {
    final bytes = utf8.encode(reference.toLowerCase().trim());
    return '${sha256.convert(bytes)}.mp3';
  }
}

/// Base exception for ESV audio fetch/cache failures.
class EsvAudioException implements Exception {
  const EsvAudioException(this.message);
  final String message;

  @override
  String toString() => 'EsvAudioException: $message';
}

/// Thrown when the user has not yet consented to ESV network requests.
class EsvAudioConsentRequired extends EsvAudioException {
  const EsvAudioConsentRequired() : super('ESV audio consent not granted.');
}
