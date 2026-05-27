# Verse Management

## Summary
Verse management covers the full lifecycle of a verse: pre-loaded Navigator memory packs, selecting the current verse of the week, tracking memorized verses, and adding custom verses. It is the foundation all other features build on.

## Users / Use Cases
- **Solo user**: browses available verses from packs, designates one as the verse of the week, marks verses as memorized, and optionally adds verses not in any pack.

## Technologies
- sqflite — persists verse state (memorized, current, custom) in local SQLite
- JSON asset files — source of truth for Navigator pack content at install time

## Technical Overview
On first launch, the app seeds the SQLite database from bundled JSON pack assets. Each verse row tracks: reference, text (all three versions), pack membership, memorized flag, memorized date, and a flag for whether it is the active verse-of-the-week. The UI exposes two primary lists and an add flow.

## Key Files
| File | Purpose |
|---|---|
| `assets/packs/*.json` | Navigator TMS pack definitions (reference, ESV/CSB/NLT text, topic) |
| `lib/data/verse_dao.dart` | CRUD operations for verses |
| `lib/data/seed.dart` | One-time DB seed from asset JSON on first run |
| `lib/features/verse_management/` | UI screens: available list, memorized list, add verse, verse detail |
| `lib/models/verse.dart` | Verse domain model |

## Technical Detail

### Pack Structure (JSON)
```json
{
  "pack": "TMS Series 1",
  "verses": [
    {
      "reference": "2 Timothy 3:16",
      "esv": "All Scripture is breathed out by God...",
      "csb": "All Scripture is inspired by God...",
      "nlt": "All Scripture is inspired by God..."
    }
  ]
}
```

### Lists
- **Available verses**: all pack verses not yet memorized, grouped by pack/topic.
- **Memorized verses**: verses marked memorized, sorted by memorized date descending.

### Verse of the Week
Exactly one verse is flagged `is_current = true` at any time. Setting a new verse of the week clears the previous flag. The current verse is surfaced prominently on the home screen.

### Adding Custom Verses
Users can enter a reference and text manually. Custom verses are stored in the same table with `is_custom = true` and no pack membership. Bible version must be specified at entry.

### Selecting Next Verse
From the available list, tapping a verse and confirming sets it as the verse of the week. It does not automatically mark the previous one as memorized — the user does that explicitly.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
