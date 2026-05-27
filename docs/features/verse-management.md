# Verse Management

## Summary
Verse management covers the full lifecycle of a verse: pre-loaded Navigator memory packs, selecting the current verse of the week, tracking memorized verses, and adding custom verses. It is the foundation all other features build on.

## Users / Use Cases
- **Solo user**: browses available verses from packs, designates one as the verse of the week, marks verses as memorized, and optionally adds verses not in any pack.

## Technologies
- `sqflite_sqlcipher` — encrypted SQLite; key generated per-install and stored in Android Keystore via `flutter_secure_storage`
- JSON asset files — source of truth for Navigator pack content at install time
- Provider — `VerseProvider` exposes verse state to all screens

## Technical Overview
On first launch, the app seeds the SQLite database from bundled JSON pack assets. `DatabaseHelper` is a singleton that initialises the cipher key from Android Keystore on every open. Each verse row tracks: reference, text (all three versions), pack membership, memorized flag, memorized date, and a flag for whether it is the active verse-of-the-week. The UI exposes two primary lists and an add flow via named routes.

## Key Files
| File | Purpose |
|---|---|
| `assets/packs/*.json` | Navigator TMS pack definitions (reference, ESV/CSB/NLT text, topic) |
| `lib/data/database_helper.dart` | Singleton; opens encrypted DB, runs migrations |
| `lib/data/verse_dao.dart` | CRUD operations for verses |
| `lib/data/seed.dart` | One-time DB seed from asset JSON on first run |
| `lib/features/verse_management/home_screen.dart` | Verse-of-week card, quick-action buttons, recent memorized chips |
| `lib/features/verse_management/verses_screen.dart` | TabBar: Memorized tab + Available tab, search bar |
| `lib/features/verse_management/add_verse_screen.dart` | Manual reference + text entry, version picker |
| `lib/features/verse_management/verse_detail_screen.dart` | Full verse display, mark-memorized action |
| `lib/models/verse.dart` | Verse domain model |
| `lib/providers/verse_provider.dart` | Provider; exposes lists, current verse, mutation methods |

## Technical Detail

### Encryption
`DatabaseHelper` calls `flutter_secure_storage` to read (or generate and store) a random 256-bit key on each DB open. The key never leaves the Keystore-backed secure element. `android:allowBackup="false"` in the manifest prevents the encrypted DB from appearing in cloud or ADB backups.

### Screen Structure and Routes
| Route | Screen | Description |
|---|---|---|
| `/` | `HomeScreen` | Verse-of-week card, quick actions, recent memorized chips |
| `/verses` | `VersesScreen` | TabBar: Memorized \| Available, search field |
| `/verses/add` | `AddVerseScreen` | Form to add a custom verse |
| `/verses/detail` | `VerseDetailScreen` | Full verse; mark memorized action |

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
| 2026-05-27 | Updated with full implementation: encryption details, DatabaseHelper singleton, screen/route table, Provider integration |
