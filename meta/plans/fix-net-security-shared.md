# Plan: Shared network-security/exception-layering cleanups

**Issues:** #72, #74, #76

---

## Goal

Close three small but security/architecture-relevant gaps surfaced by SDLC review: a duplicated SSRF allowlist guard, a layering inversion in the database helper, and an unguarded `launchUrl` call.

---

## Context

Three findings from the ESV-integration review touch network/security hygiene in unrelated files but share a "duplication/layering" theme: the https+host allowlist check is copy-pasted across three services (#72), `database_helper.dart` reaches into a service-layer exception type just to reuse it (#74), and Settings' "ESV.org" link has no failure handling unlike every other network call in the branch (#76). None require UI changes; all are internal hardening.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/net_security.dart` (new) | Add shared `assertAllowedHttpsHost(Uri uri, Set<String> allowedHosts)` helper |
| `lib/services/bible_lookup_service.dart` | Replace inline scheme/host guard with call to shared helper |
| `lib/services/esv_lookup_service.dart` | Replace inline scheme/host guard with call to shared helper |
| `lib/services/esv_audio_cache_service.dart` | Replace inline scheme/host guard with call to shared helper |
| `lib/database/database_helper.dart` | Remove `LookupException` import; throw new DB-owned exception (e.g. `EsvVerseCapExceededException`) on cap-exceeded in `insertEsvVerse` |
| `lib/providers/verse_provider.dart` / `lib/screens/verses/add_verse_screen.dart` | Catch the new DB exception type instead of `LookupException` where the cap error is surfaced |
| `lib/screens/settings/settings_screen.dart` | Guard the "ESV.org" `ListTile.onTap` `launchUrl` call with `canLaunchUrl` or try/catch; show a fallback message on failure |

### Steps

1. Add `lib/services/net_security.dart` with `assertAllowedHttpsHost(Uri uri, Set<String> allowedHosts)` that throws on non-https scheme or host not in the allowlist. Port the exact validation logic currently duplicated in the three services.
2. Update `bible_lookup_service.dart`, `esv_lookup_service.dart`, and `esv_audio_cache_service.dart` to call the shared helper instead of their inline checks. Keep each service's own allowlisted host set.
3. In `database_helper.dart`, define a DB-layer exception (e.g. `EsvVerseCapExceededException`) and throw it from `insertEsvVerse` instead of `LookupException`. Remove the now-unused import.
4. Update callers that catch `LookupException` from `insertEsvVerse` (search `VerseProvider`/`AddVerseScreen`) to catch the new exception type and produce the same user-facing message as before.
5. In `settings_screen.dart`, wrap the "ESV.org" tap handler with `canLaunchUrl` (or try/catch around `launchUrl`) and show a `SnackBar`/dialog fallback message on failure, consistent with the defensive style in `EsvAudioCacheService`.

---

## Acceptance Criteria

- [ ] A single shared function enforces scheme==https and host-in-allowlist; no service has its own inline copy
- [ ] `database_helper.dart` no longer imports any service-layer exception type
- [ ] Cap-exceeded errors still produce the same user-facing message as before the exception-type change
- [ ] Tapping "ESV.org" when no handler is available shows a fallback message instead of throwing
- [ ] Existing tests for all three network services and the cap-enforcement path still pass
