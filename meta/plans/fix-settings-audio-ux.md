# Plan: Settings Screen — Reminder Banner Correctness, Audio-Row Accessibility, and Design Consistency

**Issues:** #168, #169, #176, #177, #178, #179, #181, #182, #183, #184, #186

---

## Goal

The audio and notification sections of Settings behave correctly when toggled off, describe their state to screen readers and low-vision users as well as to sighted ones, and follow the project's own design and style conventions — with the interaction paths under test.

---

## Context

The notifications + periodic-audio-playback work (#163, #164) landed a new interval picker, trigger-mode chips, and a reminder-error banner in `SettingsScreen`. The follow-up SDLC review found one user-visible correctness bug and a cluster of accessibility, design, and style defects concentrated in that one file. The correctness bug: a reminder-scheduling failure sets an error banner that is never cleared when the user turns the reminder off, so Settings indefinitely instructs the user to grant a permission for a reminder that no longer exists. The accessibility defects share a root cause — the new rows convey their disabled and error states visually only, and the interval row emits three unrelated static semantic nodes with no button role. The remaining findings are convention drift (a Lora scripture-typography role applied to numeric UI chrome, a no-op `MergeSemantics`, a `context` parameter shadowing `State.context`) plus an undocumented dialog-commit convention. All of it lives in `SettingsScreen`, and the new interval dialog and trigger chips have zero interaction coverage — so the tests come in with the fixes rather than after them.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/settings_screen.dart` | Clear `_reminderError` on every reminder-off path; render `InlineStatusBanner` unconditionally; associate the error with the reminder tile; add `enabled` to the trigger-chip semantics; add disabled-state subtitle copy; merge the interval tile into one button-role semantic node; swap `tt.bodyMedium` → sans label role on trailing values; rename the shadowing `context` param |
| `test/screens/settings/settings_screen_test.dart` | Interaction tests for the interval dialog, trigger chips, disabled no-op, and the deny-then-clear banner sequence |
| `meta/DESIGN_BRIEF.md` | Document the chip-dialog commit convention in §7 and its carve-out from Action Pairs |
| `docs/features/notifications.md` | Note the reminder-error lifecycle and tile association |
| `docs/features/audio.md` | Note the disabled-state and semantics treatment of the audio rows |

### Steps

1. **Reminder error lifecycle (#168, #181, #178).** Take these together — they're three faces of one banner.
   - Reset the reminder-error state to null in the clear-reminder handler, and at the top of the null-`dailyNotificationTime` branch of the apply-notification-settings helper, before its early return.
   - Drop the `if (_reminderError != null)` wrapper around `InlineStatusBanner` and render it unconditionally, passing the nullable message. The widget already collapses to `SizedBox.shrink()` on null and documents that always-mounted is its intended contract (the add-verse screen already honors it). Preserve the horizontal padding without introducing vertical space when collapsed.
   - Fold the error into the reminder time-picker tile's own semantic label when non-null, so it's discoverable from the control later in the session and not only via the one-shot live-region announcement. Watch for double-announcement on the initial transition.

2. **Audio-row disabled state (#176, #177).**
   - Add `enabled: settings.audioInterruptEnabled` to the `Semantics` node wrapping the trigger-mode `Wrap`, keeping its group label and `explicitChildNodes: true` (required by Design Brief §7 for preset chip rows).
   - Give the interval row and trigger-mode row a subtitle qualifier when the master switch is off — e.g. `Turn on "Play verses periodically" to configure` — so the state isn't carried by `ListTile.enabled`'s dimming alone. Read `meta/BRAND_VOICE.md` before settling the string.

3. **Interval tile semantics (#179, #184).** These two conflict on the surface and must be resolved in one edit: #184 says the trailing-only `MergeSemantics` is a no-op to delete, #179 says merge the whole tile. Merging the whole tile satisfies both. Wrap the interval `ListTile` in a single `Semantics(button: true, ...)` + `MergeSemantics`, matching the pattern the "Notification type" and "Theme" rows already use, with a label composed from the live interval value. Remove the trailing-only wrapper. Apply the same treatment to the sibling "Verse-of-week probability" row, which has the identical shape.

4. **Typography (#183).** Replace the explicit `tt.bodyMedium` on the trailing value text of the interval and probability rows with a sans role — `tt.labelMedium` per the brief's "Chip labels, badges" usage. `bodyMedium` maps to Lora, reserved for verse text; it renders correctly today only by coincidence of the `ListTile` default.

5. **Naming (#186).** Rename the interval dialog's `BuildContext context` parameter to `launchContext` so it stops shadowing `State.context`, and drop the `this.context` qualifier at the post-await tracking restart. Add one short comment stating why the `State` context is the right one after the dialog resolves — the launch context may be gone. Treat the sibling probability dialog consistently.

6. **Design Brief (#182).** No code change. Document in §7 "Chips" that a dialog whose content is a discrete preset chip list commits on tap and pops with Cancel as the sole escape, while dialogs built on continuous inputs (sliders, text fields) follow Action Pairs with an explicit Save. Note the carve-out in the Action Pairs section so the two don't appear to contradict. Rationale is on #182: the two dialogs differ because their input controls differ — a chip tap is an unambiguous discrete decision; a slider drag is exploratory and needs an explicit commit.

7. **Interaction tests (#169).** Write against the post-fix shape of the screen, not the current markup. Cover: preset selection persists the interval and dismisses the dialog; Cancel leaves it unchanged (null-selection early return); a chip tap persists the mode and flips both chips' `selected`; a chip tap while disabled is a no-op on both persistence and tracking; a null verse-of-week no-ops the tracking restart rather than throwing. Assert against the `SettingsProvider`'s persisted `AppSettings` and injected fakes' recorded calls — not private screen state. `AudioInterruptService` already accepts `systemAudioService`, `debounceDelay`, and `debounceSamples`, and exposes a `@visibleForTesting` fire hook; reuse those seams.

8. Run `dart format .` and `flutter analyze` before finishing.

---

## Acceptance Criteria

- [ ] A failed schedule followed by turning the reminder off removes the error banner; a later successful schedule still clears it.
- [ ] `InlineStatusBanner` is mounted regardless of error state, collapses invisibly with no stray vertical space, and both of its call sites use the same unconditional pattern.
- [ ] With an error present, the reminder tile's own semantics include the message.
- [ ] With the master switch off, the trigger-chip group reports disabled and both dependent rows state their unavailability in text.
- [ ] The interval row exposes one merged semantic node with a button role and a label carrying the live value; no `MergeSemantics` wraps a single leaf child anywhere in the file.
- [ ] No settings-screen UI-chrome text requests a Lora-mapped role.
- [ ] No method in `SettingsScreen` declares a `context` parameter shadowing `State.context`.
- [ ] `meta/DESIGN_BRIEF.md` states the chip-dialog commit rule and its Action Pairs carve-out; neither dialog's runtime behavior changes.
- [ ] Interval dialog and trigger-mode handler are no longer at 0% coverage; all five interaction paths from step 7 are tested.
- [ ] `flutter test` passes; `flutter analyze` clean; `dart format --output=none --set-exit-if-changed .` exits zero.

---

## Pre-Implementation Review

No new `/sdlc` plan-review pass was dispatched: these issues **are** the output of a completed seven-agent SDLC review of this iteration (see `sdlc_review_completed_agents` in `prd.json`), so a fresh security/privacy/a11y/design sweep over the same diff would be circular. Findings carried forward from triage-time verification:

- **Accessibility (#179 vs #184 conflict — must resolve together).** The two issues prescribe opposite-looking edits on the same widget. Deleting the `MergeSemantics` without adding tile-level semantics (the #184-only reading) would strip the row's value announcement and make accessibility *worse*. Implement the whole-tile merge once.
- **Accessibility (#178 double-announcement risk).** Adding the error to the tile's semantic label alongside a live-region banner can produce a duplicated read on the initial transition. Verify with a semantics test.
- **Design (#182 — decision made during triage, not derived from an existing rule).** The Design Brief was silent on dialog commit semantics; the recommendation to keep immediate-commit is reasoned on the discrete-vs-continuous input distinction. Reversible and low-cost if the maintainer prefers a Save button — flag at PR review.
- **Design (#183).** The `bodyMedium` → Lora mapping is confirmed in Design Brief §4. The finding is latent, not currently visible: it renders correctly today and only bites on a future retune of the verse-preview role.
- **Scope note (#177 / #175 copy collision).** #175 (in `docs-privacy-audio-disclosure.md`) also edits audio-section subtitle copy. That plan is sequenced after this one; expect to reconcile the final subtitle strings there.
