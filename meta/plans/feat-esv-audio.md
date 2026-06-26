# Plan: ESV Audio Playback

**Issues:** #70
**Prerequisite:** Complete feat/esv-lookup (#67) first — ESV verses must exist in the database before audio can be tested end-to-end.

---

## Goal

ESV verses play a real Crossway MP3 recording during the text phase; non-ESV verses and offline ESV verses fall back to TTS transparently, with no change to the user-visible playback flow.

---

## Context

`AudioService` drives a TTS state machine: speak reference → pause → speak text → completed. For ESV, the text phase should play the real Crossway recording rather than synthesized speech. A new `EsvAudioCacheService` handles fetching and caching MP3s from `api.esv.org/v3/passage/audio/`. The `audioplayers` package plays local MP3 files. All other translations and offline ESV fall back to TTS with no error shown to the user. The interruption feature and review play screen call `AudioService.playVerse` — they pick up ESV audio automatically with no additional wiring.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/esv_audio_cache_service.dart` | New: fetch, redirect-split, cache MP3s |
| `lib/services/audio_service.dart` | ESV branch in `speakingText` phase; `audioplayers` integration |
| `pubspec.yaml` | Add `audioplayers: ^6.0.0` |
| `meta/PRIVACY.md` | Add ESV audio network requests, CDN host, audio cache row |
| `android/app/src/main/AndroidManifest.xml` | Update INTERNET comment to name ESV audio |
| `docs/features/audio.md` | Document ESV audio branch |
| `test/services/esv_audio_cache_service_test.dart` | New: cache service unit tests |
| `test/providers/audio_provider_test.dart` | Add ESV audio branch tests |

### Steps

1. **`pubspec.yaml`:**
   ```yaml
   audioplayers: ^6.0.0
   ```

2. **`lib/services/esv_audio_cache_service.dart` — new service:**

   **Cache key** — use SHA-256 of the normalized reference (NOT the raw reference string) as the filename. This prevents path traversal since `sha256.convert(...)` produces 64 safe hex chars. (`crypto` package is already in `pubspec.yaml`.)
   ```dart
   String _cacheKey(String reference) {
     final bytes = utf8.encode(reference.toLowerCase().trim());
     return '${sha256.convert(bytes)}.mp3';
   }
   ```

   **Two-request pattern** — do NOT forward the `Authorization` header to the redirect target:
   ```dart
   // Step 1: resolve the redirect URL (with auth to ESV API)
   final resolveRequest = http.Request('GET', _audioUri(reference))
     ..headers['Authorization'] = 'Token $_apiKey'
     ..followRedirects = false;
   final resolveResponse = await _client.send(resolveRequest);
   if (resolveResponse.statusCode != 301 && resolveResponse.statusCode != 302) {
     throw EsvAudioException('Unexpected status: ${resolveResponse.statusCode}');
   }
   final location = resolveResponse.headers['location'];
   if (location == null) throw EsvAudioException('No redirect location');

   // Step 2: fetch MP3 from CDN without the API key
   final audioUri = Uri.parse(location);
   _assertAllowedAudioHost(audioUri); // SSRF guard on redirect target
   final audioResponse = await _client.get(audioUri)
       .timeout(const Duration(seconds: 30));
   if (audioResponse.statusCode != 200) {
     throw EsvAudioException('Audio fetch failed (${audioResponse.statusCode})');
   }
   ```

   **Redirect host allowlist** — check against known ESV CDN hosts before following redirect. Discover the actual CDN hostname from a live API response before hardcoding. Pattern mirrors `BibleLookupService._assertHttps`:
   ```dart
   static const _allowedAudioHosts = {'audio.esv.org'}; // verify actual host
   void _assertAllowedAudioHost(Uri uri) {
     if (uri.scheme != 'https') throw EsvAudioException('Non-HTTPS redirect');
     if (!_allowedAudioHosts.contains(uri.host)) {
       throw EsvAudioException('Unexpected audio host: ${uri.host}');
     }
   }
   ```
   Update `_allowedAudioHosts` after inspecting a live response.

   **Cache read/write:**
   ```dart
   Future<String> getAudioPath(String reference) async {
     final cacheDir = await getApplicationCacheDir();
     final audioDir = Directory(path.join(cacheDir.path, 'esv_audio'));
     await audioDir.create(recursive: true);

     final file = File(path.join(audioDir.path, _cacheKey(reference)));
     if (await file.exists()) return file.path; // cache hit

     // Evict oldest files if over cap before writing new one
     await _evictIfNeeded(audioDir, maxFiles: 250);

     // ... fetch and write ...
     await file.writeAsBytes(audioResponse.bodyBytes);
     return file.path;
   }
   ```

   **In-flight deduplication** — prevent concurrent fetches for the same verse:
   ```dart
   final Map<String, Future<String>> _inFlight = {};

   Future<String> getAudioPath(String reference) {
     return _inFlight.putIfAbsent(reference, () async {
       try {
         return await _fetchAndCache(reference);
       } finally {
         _inFlight.remove(reference);
       }
     });
   }
   ```

   **Cache size limit** — evict oldest files when count exceeds 250:
   ```dart
   Future<void> _evictIfNeeded(Directory dir, {required int maxFiles}) async {
     final files = await dir.list().whereType<File>().toList();
     if (files.length < maxFiles) return;
     files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
     for (final f in files.take(files.length - maxFiles + 1)) {
       await f.delete();
     }
   }
   ```

   **First-use consent:** Before the first network call, check `SharedPreferences` for `'esv_audio_consent_v1'`. If absent, throw `EsvAudioConsentRequired` — the caller (AudioService) catches this and prompts consent before retrying. Alternatively, gate on the existing `esv_lookup_consent_v1` if ESV audio consent is considered implied by text lookup consent. Decide at implementation time; whichever key is used, document it in `meta/PRIVACY.md`.

3. **`lib/services/audio_service.dart` — ESV branch in `speakingText` phase:**

   Inject `EsvAudioCacheService` via constructor parameter (defaults to `null`; AudioService constructs one if not provided). This keeps the service testable.

   In `playVerse`, replace the `speakingText` TTS call:
   ```dart
   _emit(AudioPlaybackState.speakingText);
   _pausedPhase = _PlayPhase.text;

   if (verse.translation == 'ESV' && _esvAudio != null) {
     try {
       final path = await _esvAudio!.getAudioPath(verse.reference);
       if (_isStopped) return;
       await _playMp3AndWait(path);
     } catch (_) {
       // Offline or fetch failed — fall back to TTS silently
       if (_isStopped) return;
       await _speakAndWait(verse.text);
     }
   } else {
     await _speakAndWait(verse.text);
   }
   if (_isStopped) return;
   ```

   `_playMp3AndWait(String path)`:
   ```dart
   Future<void> _playMp3AndWait(String path) async {
     final completer = Completer<void>();
     final player = AudioPlayer();
     player.onPlayerComplete.listen((_) => completer.complete());
     await player.play(DeviceFileSource(path));
     _activePlayer = player;
     await completer.future;
     await player.dispose();
     _activePlayer = null;
   }
   ```

   `stop()` must also stop `_activePlayer`:
   ```dart
   Future<void> stop() async {
     _isStopped = true;
     await _activePlayer?.stop();
     await _activePlayer?.dispose();
     _activePlayer = null;
     await _tts.stop();
     _emit(AudioPlaybackState.idle);
   }
   ```

   Apply the same `_activePlayer` handling in `pause()` and `resume()` for the text phase.

4. **`meta/PRIVACY.md` updates:**
   - Add `api.esv.org` (ESV audio endpoint) and the CDN host to network recipients
   - Add consent mechanism description (`esv_audio_consent_v1` or shared with lookup consent)
   - Add row to data-stored table: ESV verse audio cache — `getApplicationCacheDir()/esv_audio/` — purpose: audio playback — retention: evicted by OS under storage pressure or when cache exceeds 250 files; not backed up (excluded from Auto Backup)

5. **`docs/features/audio.md`** — add a section describing the ESV MP3 branch, cache service, fallback behavior, and the two-request redirect pattern.

### Tests

`test/services/esv_audio_cache_service_test.dart`:
- Cache miss: fetches from network, writes file, returns path
- Cache hit: returns path without making a second HTTP call
- Authorization header NOT forwarded to redirect host
- Network failure → `EsvAudioException` thrown
- Path traversal prevention: reference with `/` or `..` produces a safe hash filename (verify no `..` in output)
- In-flight deduplication: two concurrent calls for same reference share one fetch

`test/providers/audio_provider_test.dart` (extend via `FakeAudioService`):
- ESV verse + cache service returns path → `playVerse` reaches `AudioPlaybackState.completed`
- ESV verse + cache service throws → falls back to TTS and still reaches `completed`
- Non-ESV verse → cache service never called (TTS only)

---

## Acceptance Criteria

- [ ] `audioplayers` added to `pubspec.yaml`
- [ ] Playing an ESV verse (online, cache miss) → cache service fetches MP3; text phase plays the file; state machine reaches `completed`
- [ ] Playing the same ESV verse again (cache hit) → no network call; plays from cache
- [ ] Playing an ESV verse offline → TTS fallback; playback still completes normally; no error shown to user
- [ ] Playing BSB/KJV/WEB verse → TTS for both phases; no regression
- [ ] `stop()` during ESV audio phase halts playback and emits `idle`
- [ ] `pause()`/`resume()` during ESV audio phase behaves consistently with TTS contract
- [ ] Audio interruption and review play automatically use ESV MP3 for ESV verses
- [ ] `meta/PRIVACY.md` updated with ESV audio network hosts and cache data row
- [ ] `flutter test` passes; all new tests green

---

## Pre-Implementation Review

**Security — HIGH: Authorization header must not be forwarded to CDN.** Use the two-request pattern: Step 1 fetches with auth and `followRedirects = false`; Step 2 fetches the MP3 from the CDN URL without auth. Dart's `http` client forwards headers through redirects by default — this is exploitable if api.esv.org is ever compromised or misconfigured.

**Security — HIGH: API key storage.** The ESV API key is currently compile-time injected via `dart-define`. For audio this is the same key already used for text lookup. No additional key management needed beyond what feat/esv-lookup establishes — document that the key is embedded in the binary and build in key rotation capability (new `ESV_API_KEY_VERSION` param) so old builds can be invalidated.

**Security — MEDIUM: Path traversal via reference-as-filename.** Use `sha256.convert(utf8.encode(ref.toLowerCase().trim())).toString()` as the cache filename. The `crypto` package is already in `pubspec.yaml`. Never use the raw reference string as a path component.

**Security — MEDIUM: Redirect host allowlist.** Validate the `Location` header before following it. Discover the actual CDN hostname from a live ESV audio API response; hardcode in `_allowedAudioHosts`. This mirrors the SSRF guard in `BibleLookupService`.

**Security — MEDIUM: Cache size limit.** Evict the oldest files when count exceeds 250 (~30 MB worst case at 120 KB/file). Without eviction, the cache grows unboundedly.

**Privacy — MEDIUM: First-use consent gate.** The audio endpoint sends the verse reference and IP to Crossway without user consent if not gated. Check `esv_audio_consent_v1` (or reuse `esv_lookup_consent_v1`) before first request. Update `meta/PRIVACY.md`.

**Security — LOW: In-flight deduplication.** Use a `Map<String, Future<String>> _inFlight` to prevent concurrent duplicate fetches for the same verse during pause/resume cycles.
