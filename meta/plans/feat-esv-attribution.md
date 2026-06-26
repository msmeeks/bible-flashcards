# Plan: ESV Attribution Footer

**Issues:** #68
**Prerequisite:** Complete feat/esv-lookup (#67) first — the footer needs ESV verses to test against.

---

## Goal

Every screen that displays ESV verse text shows a collapsible Crossway attribution footer; the footer is absent on non-ESV screens and collapses permanently after the user first dismisses it.

---

## Context

Crossway's ESV API terms require a copyright notice on every page displaying ESV text, with a link to www.esv.org. The footer must be a reusable widget to avoid per-screen drift. After the user collapses it once, the widget initializes collapsed on all future visits across all screens, satisfying the "acknowledge once" UX goal. A full copyright notice and tappable www.esv.org link live in Settings for reference.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/widgets/esv_copyright_footer.dart` | New: reusable collapsible attribution widget |
| `lib/screens/settings/settings_screen.dart` | New ESV Bible section with full notice + browser link |
| `lib/screens/verses/add_verse_screen.dart` | Wire footer (visible when ESV preview is shown) |
| `lib/screens/verses/verse_detail_screen.dart` | Wire footer (visible when verse.translation == 'ESV') |
| `lib/screens/test/test_session_screen.dart` | Wire footer (visible when current verse is ESV) |
| `lib/screens/review/review_show_screen.dart` | Wire footer (visible when any session verse is ESV) |
| `lib/screens/review/review_play_screen.dart` | Wire footer (visible when any session verse is ESV) |
| `pubspec.yaml` | Add `url_launcher: ^6.3.0` as explicit direct dependency |
| `android/app/src/main/AndroidManifest.xml` | Add `<queries>` https intent for url_launcher on Android 11+ |
| `test/widgets/esv_copyright_footer_test.dart` | New: widget tests |

### Steps

1. **`pubspec.yaml` — add url_launcher:**
   ```yaml
   url_launcher: ^6.3.0
   ```
   Run `flutter pub get` and confirm `url_launcher_android` appears in the lock file.

2. **`android/app/src/main/AndroidManifest.xml` — add https queries intent:**
   Inside the existing `<queries>` block:
   ```xml
   <intent>
     <action android:name="android.intent.action.VIEW" />
     <data android:scheme="https" />
   </intent>
   ```
   Without this, `canLaunchUrl` silently returns false on Android 11+.

3. **`lib/widgets/esv_copyright_footer.dart` — new widget:**

   Accepts `bool hasEsvContent`. Renders nothing when false.

   State: reads/writes `SharedPreferences` key `esv_footer_collapsed_v1`. On first render (key absent), defaults to expanded.

   **Collapsed state:**
   ```dart
   Semantics(
     button: true,
     expanded: false,
     label: 'ESV copyright notice. Collapsed. Activate to expand.',
     child: InkWell(
       onTap: _expand,
       child: SizedBox(
         height: 48, // 48dp minimum tap target
         child: Row(
           children: [
             const SizedBox(width: 16),
             Text('ESV®', style: tt.labelSmall),
             const SizedBox(width: 4),
             ExcludeSemantics(
               child: Icon(Symbols.expand_more_rounded, size: 16),
             ),
           ],
         ),
       ),
     ),
   )
   ```

   **Expanded state:**
   ```dart
   Semantics(
     expanded: true,
     label: 'ESV copyright notice. Expanded.',
     child: Padding(
       padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Expanded(
                 child: Text(
                   'Scripture quotations are from the ESV® Bible, '
                   '© 2001 by Crossway. Used by permission.',
                   style: tt.labelSmall,
                 ),
               ),
               IconButton(
                 tooltip: 'Collapse copyright notice',
                 icon: const Icon(Symbols.expand_less_rounded, size: 16),
                 onPressed: _collapse,
               ),
             ],
           ),
           Semantics(
             label: 'View full ESV copyright terms in Settings',
             child: TextButton(
               onPressed: _navigateToEsvSettings,
               child: const Text('Full terms in Settings'),
             ),
           ),
         ],
       ),
     ),
   )
   ```

   **Live region sibling** — always in tree, receives a new label on every toggle:
   ```dart
   Semantics(
     liveRegion: true,
     label: _collapsed
         ? 'ESV copyright notice collapsed'
         : 'ESV copyright notice expanded',
     child: const SizedBox.shrink(),
   ),
   ```

   **Animation** — wrap the expanded content in `AnimatedSize` if reduced-motion is off:
   ```dart
   final reducedMotion = MediaQuery.of(context).disableAnimations;
   reducedMotion
       ? _buildContent()
       : AnimatedSize(
           duration: const Duration(milliseconds: 200),
           alignment: Alignment.topCenter,
           child: _buildContent(),
         )
   ```

   **`_navigateToEsvSettings`:** push a named route or `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))`. The Settings ESV section scrolls into view using a `ScrollController` or `GlobalKey` if needed — simplest is just navigating to Settings and trusting the user to find the section.

4. **`lib/screens/settings/settings_screen.dart` — ESV Bible section:**
   Add a new `_SectionHeader(label: 'ESV Bible')` and a `ListTile` below the About section:
   ```dart
   _SectionHeader(label: 'ESV Bible', textTheme: tt),
   ListTile(
     title: const Text(
       'Scripture quotations are from the ESV® Bible '
       '(The Holy Bible, English Standard Version®), '
       '© 2001 by Crossway, a publishing ministry of '
       'Good News Publishers. Used by permission. All rights reserved.',
     ),
   ),
   ListTile(
     title: const Text('ESV.org'),
     subtitle: const Text('Full terms and copyright'),
     trailing: const Icon(Symbols.open_in_new_rounded),
     onTap: () async {
       final uri = Uri.parse('https://www.esv.org');
       await launchUrl(uri, mode: LaunchMode.externalApplication);
     },
   ),
   ```

5. **Wire to screens** — place `EsvCopyrightFooter` at the bottom of each screen's scaffold body (in `Column` or as the last child in the scroll view):
   - **AddVerseScreen:** `hasEsvContent: _translation == 'ESV' && _preview != null`
   - **VerseDetailScreen:** `hasEsvContent: verse.translation == 'ESV'`
   - **TestSessionScreen:** `hasEsvContent: currentVerse.translation == 'ESV'`
   - **ReviewShowScreen:** `hasEsvContent: sessionVerses.any((v) => v.translation == 'ESV')`
   - **ReviewPlayScreen:** `hasEsvContent: sessionVerses.any((v) => v.translation == 'ESV')`

### Tests

`test/widgets/esv_copyright_footer_test.dart` — follow `confidence_badge_test.dart` pattern:
- `hasEsvContent: false` → widget not in tree at all
- Pref absent (first run) → expanded state rendered
- `esv_footer_collapsed_v1 = true` → collapsed chip rendered
- Tap collapsed chip → expanded content appears, pref set to false
- Tap collapse icon → collapsed chip appears, pref set to true
- "Full terms in Settings" TextButton present in expanded state
- Live region node present in both states

---

## Acceptance Criteria

- [ ] `EsvCopyrightFooter` renders nothing when `hasEsvContent` is false
- [ ] First render (no pref): footer shows expanded copyright notice and "Full terms in Settings" button
- [ ] Collapsing the footer sets `esv_footer_collapsed_v1 = true`; reopening the screen shows it collapsed
- [ ] Expanding from collapsed state shows full copyright text
- [ ] "Full terms in Settings" navigates to the ESV Bible section in Settings
- [ ] Settings screen shows full Crossway copyright notice and tappable "ESV.org" link that opens the browser
- [ ] Footer appears correctly on: Add Verse (when ESV preview shown), verse detail (ESV verse), test session (ESV verse under test), review show and play (any ESV verse in session)
- [ ] All icon-only controls have semantic labels; tap targets are 48dp minimum
- [ ] `flutter test` passes; widget tests cover all toggle states

---

## Pre-Implementation Review

**Security — MEDIUM: `url_launcher` must be an explicit dependency.** `url_launcher_android` is currently absent from the lock file (only pulled in transitively by `share_plus`). Add `url_launcher: ^6.3.0` explicitly to `pubspec.yaml`.

**Security — MEDIUM: Android 11+ `<queries>` intent.** Without the `android.intent.action.VIEW` + `https` scheme entry in `<queries>`, `canLaunchUrl` returns false on all modern Android devices and the ESV.org link silently does nothing.

**Security — INFO: Use `LaunchMode.externalApplication`.** Prevents accidental regression to in-app WebView in future code changes.

**A11y — BLOCKER: Touch target.** The collapsed chip must be at least 48dp tall. Wrap in `SizedBox(height: 48)` with `InkWell` as the full tap surface.

**A11y — BLOCKER: Interactive role.** Use `InkWell` + `Semantics(button: true, expanded: ...)` on the collapsed state; `Chip` alone carries no interactive role and TalkBack will not focus it.

**A11y — MAJOR: Live region on toggle.** A sibling `Semantics(liveRegion: true)` node must receive a new label string on every expand/collapse — same pattern as `verse_card.dart` lines 162–167.

**A11y — MAJOR: Expanded/collapsed state in semantic tree.** The toggle control must declare `expanded: bool` in its `Semantics` wrapper so TalkBack announces the current state.

**A11y — MAJOR: Icon-only controls must have tooltips/labels.** Use `IconButton(tooltip: '...')` or `ExcludeSemantics` on decorative icons inside a labeled container.

**A11y — MINOR: Animate only when `MediaQuery.disableAnimations` is false.** Same pattern as `verse_card.dart`.
