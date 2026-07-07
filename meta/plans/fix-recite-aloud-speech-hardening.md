# Plan: Recite-Aloud Speech Recognition Hardening and Test Coverage

**Issues:** #143, #144, #152, #154, #157

---

## Goal

The recite-aloud test session has full test coverage for its permission/availability branches, a responsive manual stop control, a documented pause-duration rationale, and consistent iconography — closing the remaining gaps from the #134-136 recite-aloud speech fix.

---

## Context

Several small, related gaps remain in `lib/screens/test/test_session_screen.dart` and `lib/services/speech_recognition_service.dart` from the recite-aloud speech recognition work on this branch:

- The transient mic-permission-`denied` branch and the `listen()`-returns-`false` (recognizer unavailable) branch both lack test coverage — only `permanentlyDenied` is tested.
- Tapping "stop listening" restarts the same 15s wedge-detection timeout used for a stalled *start*, so an unresponsive plugin can leave the UI reading "Listening…" for up to 15s after an explicit stop.
- The 15s `pauseFor` value (chosen to match the app's mic timeout, per #134) has no comment explaining why.
- The screen mixes default Material Icons with Material Symbols Rounded, violating the design brief's icon convention.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/test/test_session_screen.dart` | Add a distinct, shorter post-stop timeout (~4s) separate from the 15s wedge-detection timeout; replace default `Icons.*` usages with Material Symbols Rounded equivalents |
| `lib/services/speech_recognition_service.dart` | Add a one-line comment explaining the 15s `pauseFor` rationale |
| `test/screens/test/test_session_screen_test.dart` (or equivalent) | Add fakes/tests for transient `denied`, `listen()` returning `false`, and the shorter post-stop timeout |

### Steps

1. Add a fake speech service returning `MicPermissionResult.denied` (transient); assert the announcement text appears and the mic-settings dialog is NOT shown (that dialog is reserved for `permanentlyDenied`).
2. Add a fake speech service whose `requestPermission()` grants but whose `listen()` resolves `false`; assert the "unavailable" announcement appears and the listening state (mic icon) resets.
3. Introduce a second, shorter timeout constant (~4s) used specifically as the post-stop safety net, distinct from the existing 15s wedge-detection timeout used at session start. Add a test asserting the shorter timeout fires when the plugin doesn't respond promptly after an explicit stop.
4. Add a one-line comment next to `pauseFor: const Duration(seconds: 15)` explaining it matches the app's mic wedge-detection timeout for consistency (see #134-136).
5. Replace `Icons.check_rounded`, `Icons.close_rounded`, and any other default-`Icons.*` usages on this screen with their Material Symbols Rounded equivalents, matching the `Symbols.mic_rounded`/`Symbols.cancel_rounded`/etc. already used elsewhere on the screen.

---

## Acceptance Criteria

- [ ] Transient mic-permission-denial branch has a passing test (announcement shown, settings dialog not shown)
- [ ] `listen()` returning `false` branch has a passing test (unavailable announcement shown, listening state resets)
- [ ] Tapping stop while the plugin is unresponsive resolves the "Listening…" state within ~4-5s, not up to 15s; the original 15s start-wedge timeout is unaffected
- [ ] A one-line rationale comment sits next to the 15s `pauseFor` value
- [ ] All icons on this screen use Material Symbols Rounded, with no visual regression in meaning/placement
