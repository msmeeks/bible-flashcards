# Plan: PRIVACY.md — Account for Other-App-Audio Detection and Boot-Completed

**Issues:** #173, #174, #175
**Prerequisite:** land `fix-settings-audio-ux.md` first — #175 edits audio-section subtitle copy that #177 also rewrites.

---

## Goal

`meta/PRIVACY.md` accurately and completely accounts for every behavior and permission the notifications and periodic-audio work introduced, including a durable rationale for why the new audio detection ships without an in-app consent notice.

---

## Context

The periodic-verse-playback work (#164) added a platform channel that polls the system for whether another app is playing audio, sampled each interval in the default trigger mode; the notifications work (#163) added `RECEIVE_BOOT_COMPLETED` and a boot receiver so the daily reminder survives a reboot. `docs/features/audio.md` was updated for the former; `meta/PRIVACY.md` was updated for neither. That document commits, in its own "Changes" clause, to being updated whenever a change introduces additional data collection — so this is a self-imposed compliance gap rather than a documentation nicety, and its "Permissions Used" table is presented as exhaustive, which stops being true the moment it silently isn't. The underlying behavior is genuinely low-risk (a boolean, no permission, nothing persisted, nothing transmitted) — the work here is to *say so* precisely, and to record why the two existing consent precedents don't extend to it.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `meta/PRIVACY.md` | Add the audio-detection "Data Collected" row and section; add the `RECEIVE_BOOT_COMPLETED` permission row; record the no-in-app-notice rationale |
| `lib/screens/settings/settings_screen.dart` | Subtitle/label copy conveying the detection mechanic (#175); no new UI |

### Steps

1. **Verify before writing.** Read `lib/services/audio_interrupt_service.dart` and `lib/services/system_audio_service.dart` and confirm every claim below against the code — a privacy document asserting something the code doesn't do is worse than one that's merely incomplete. The claims to confirm: the signal is a boolean from the system audio manager; it is held only for the duration of one interval check; it is never written to database, preferences, or logs; it is never transmitted; it requires no Android permission; it reveals only *whether* audio is playing, not what.

2. **Audio detection section (#173).** Add to `meta/PRIVACY.md`:
   - A "Data Collected" table row for the other-app-audio signal: in-memory only, retention none, purpose "decide whether to insert a memory verse into the user's listening".
   - A note that this reads live system audio state but requires no Android permission and conveys nothing about what is playing.
   - A "Data NOT Collected" clarification that no audio is captured or analyzed — the check is a system state query, not a recording. This matters: "the app checks what's playing" invites exactly that misreading, and the document should foreclose it.
   - No "Third-Party SDKs" entry — this is a first-party platform channel, not a package.
   - Match the existing voice and table structure; the engagement-log and ESV sections set the expected level of specificity.

3. **Permission table (#174).** Add the `RECEIVE_BOOT_COMPLETED` row — "Re-registers the daily reminder alarm after device reboot or app update (via `ScheduledNotificationBootReceiver`)". While in there, cross-check the whole table against `AndroidManifest.xml` and add any other missing row; the table's entire value is in being complete, so fixing one omission while leaving another defeats the exercise.

4. **No-notice rationale (#175).** Land this in the same section as step 2 — one coherent section, not two passes. State why no first-enable notice is required, with the four supporting facts (no permission, nothing persisted, nothing transmitted, boolean discarded immediately) plus the feature already being opt-in. Make the contrast explicit and durable so a future audit doesn't re-litigate it:
   - `engagement_notice_shown` was triggered by data **persisted** to the database with a 90-day retention window. Not present here.
   - The ESV consent dialogs were triggered by Art. 9 religious-practice data **transmitted to Crossway**, a third-party controller. Not present here.
   - There is no data subject right to exercise over a boolean that doesn't outlive the function call that read it.

5. **Settings copy (#175).** Ensure the trigger-mode control's copy conveys that the app checks whether other audio is playing, so an opted-in user understands the mechanic without a dialog. Existing subtitle/label surfaces only — no new UI, no consent flag, no preference key. Read `meta/BRAND_VOICE.md` first; keep it plain and non-alarming, matching surrounding rows. Reconcile against the disabled-state qualifier #177 adds to the same subtitles in `fix-settings-audio-ux.md`.

6. Run `sdlc-doc-writer` afterward to sync `docs/features/audio.md` and `docs/llms.md` if the audio feature doc's privacy framing shifts.

---

## Acceptance Criteria

- [ ] "Data Collected" has a row for the other-app-audio signal stating in-memory-only storage and no retention.
- [ ] The document states no permission is required and no audio content is accessed.
- [ ] "Data NOT Collected" explicitly rules out audio capture and analysis.
- [ ] Every permission declared in `AndroidManifest.xml` — including `RECEIVE_BOOT_COMPLETED` — has a row with an accurate reason.
- [ ] The no-notice rationale is recorded with its four supporting facts and the explicit contrast against the persisted-data and third-party-transmission precedents.
- [ ] Settings copy conveys the detection mechanic; no dialog, consent flag, or preference key is added.
- [ ] Every factual claim in the new text is verified against the services, not inferred from the issue text.

---

## Pre-Implementation Review

No new `/sdlc` plan-review pass was dispatched — these issues are the output of the completed seven-agent SDLC review of this iteration (`sdlc_review_completed_agents` in `prd.json`), and its privacy reviewer authored all three.

- **Privacy (#175 — decision made during triage; the one item here a human may want to overturn).** The report offered two acceptable resolutions (add a first-enable notice, or document why none is needed) and triage chose the latter, reasoning that both cited precedents were triggered by conditions absent here — persistence in the engagement-log case, third-party transmission in the ESV case — and that a dialog for a discarded boolean would dilute the two dialogs guarding real disclosures. The rationale is recorded on #175. **If the maintainer prefers the dialog, this plan inverts**: step 4 becomes a one-time notice gated by a new preference flag, following the `engagement_notice_shown` pattern.
- **Privacy (#175, residual).** The report's strongest point survives the decision: users carrying the old "audio-threshold interrupt" mental model may not register the new "checks whether another app is playing" mechanic. Triage classified that as a *clarity* problem rather than a consent one — which is why step 5 is copy, not UI. If the copy can't carry it, that conclusion is worth revisiting.
- **Accuracy risk (#173).** The main hazard in this plan is writing a privacy claim the code doesn't honor. Hence step 1 and the final acceptance criterion.
- **Scope collision (#175 / #177).** Both edit audio-section subtitle copy; hence the prerequisite on `fix-settings-audio-ux.md`.
- **Security / a11y.** No code behavior, data flow, permission, or interactive surface changes beyond static copy.
