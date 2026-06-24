# Habit Tracking

## Summary
Tracks daily study activity (flashcard taps and test completions) to surface streaks, weekly review counts, and 30-day test score trends. All data stays on-device in the encrypted SQLite database. Users opt in or out on first launch and can wipe all data from Settings.

## Users / Use Cases
- **User**: Views streak count, last-7-days bar chart, and 30-day test score line chart on the Activity History screen. Can toggle any chart to a DataTable for accessibility. Can clear all activity data from Settings.
- **Admin**: N/A

## Technologies
- `sqflite_sqlcipher` — stores `engagement_log` in the encrypted database
- `shared_preferences` — stores consent flag (`engagement_tracking_enabled`) and first-launch flag (`engagement_notice_shown`)
- `fl_chart` — `BarChart` (weekly reviews) and `LineChart` (test scores)
- `provider` — `TrackingProvider` exposes computed stats to `HistoryScreen`

## Technical Overview
On every flashcard tap or test completion, `DatabaseHelper.logEngagement()` upserts a daily aggregate row (date + event_type + count) and immediately purges rows older than 90 days. `TrackingProvider.load()` reads the log and test_results tables and runs three pure static methods to compute streak, weekly counts, and 30-day scores. `HistoryScreen` renders the results as charts or DataTables depending on user toggle. First-launch consent is checked in `app.dart` before the main scaffold renders; consent can be revoked by clearing data from Settings.

## API Endpoints
N/A — local SQLite only.

## Key Files
| File | Purpose |
|---|---|
| `lib/database/database_helper.dart` | `logEngagement`, `clearEngagementLog`, `getEngagementLog`, `getTestResultsRaw`, `invalidateTrackingCache` |
| `lib/providers/tracking_provider.dart` | `TrackingProvider` — loads data, exposes streak/counts/scores |
| `lib/screens/history/history_screen.dart` | `HistoryScreen` — streak card, weekly bar chart, 30-day line chart, table fallbacks |
| `lib/screens/settings/settings_screen.dart` | Activity History nav tile + Clear Activity History destructive tile |
| `lib/app.dart` | `_EngagementNoticeWrapper` — first-launch consent dialog |
| `test/providers/tracking_provider_test.dart` | Unit tests for all three static compute methods |
| `lib/utils/date_format.dart` | Shared `isoDateKey` (yyyy-MM-dd day-bucket key) and `shortDateLabel` (MM/DD chart axis label) helpers, local-calendar-day based |

## Technical Detail

### engagement_log table schema
```sql
CREATE TABLE engagement_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  date       TEXT NOT NULL,          -- 'yyyy-MM-dd'
  event_type TEXT NOT NULL,          -- 'flashcard_tap' | 'test_complete'
  count      INTEGER NOT NULL DEFAULT 1,
  UNIQUE(date, event_type)
);
```
Added in DB version 2 via `_onUpgrade`. `_createEngagementLogTable` uses `CREATE TABLE IF NOT EXISTS` so it is safe to call from both `_onCreate` and `_onUpgrade`.

### logEngagement allowlist and consent gate
`_validEventTypes = {'flashcard_tap', 'test_complete'}` — any other string is silently dropped before hitting the database. After the allowlist check, the method reads `engagement_tracking_enabled` from SharedPreferences (cached in `_trackingEnabled`; reset by `invalidateTrackingCache()` on consent change) and returns early if false. The upsert uses SQLite `ON CONFLICT DO UPDATE SET count = count + 1`.

### 90-day auto-purge
Every call to `logEngagement` deletes rows where `date < (today - 90 days)`. No background job is needed; purge is a side effect of normal usage.

### TrackingProvider static compute methods
All three are `@visibleForTesting static` so tests can call them directly without a real database.

| Method | Input | Output | Notes |
|---|---|---|---|
| `computeStreak` | `engagement_log` rows | `int` days | If today has no activity, starts from yesterday so the streak does not reset each morning before first tap |
| `computeLast7Days` | `engagement_log` rows | `List<MapEntry<String,int>>` (7 entries, oldest first) | Aggregates all event_types per day; zero-fills missing days |
| `computeLast30DaysScores` | `test_results` raw rows | `List<MapEntry<DateTime, double>>` (0.0–1.0, oldest first) | Filters by `tested_at > now - 30 days`; groups rows by local calendar day via `isoDateKey`, averages `accuracy` per day; one entry per day, sorted ascending |

### First-launch consent dialog
`_BibleFlashcardsAppState._checkEngagementNotice()` runs in `initState`. If `engagement_notice_shown` is absent or false, the `/` route renders `_EngagementNoticeWrapper` instead of `MainScaffold`. The wrapper shows a non-dismissible `AlertDialog` with "No thanks" (opt-out) and "Got it" (opt-in). Both paths write `engagement_notice_shown = true` and the chosen `engagement_tracking_enabled` value, then call `invalidateTrackingCache()` to flush the in-memory preference cache.

### Settings integration
Under the **Data** section of `SettingsScreen`:
- **Activity History** tile — navigates to `/history` (HistoryScreen)
- **Clear Activity History** tile — shows confirmation dialog; on confirm calls `DatabaseHelper().clearEngagementLog()` then `TrackingProvider.load()` to refresh UI immediately

### HistoryScreen chart/table toggle
A single `_showAsTable` bool in `_HistoryScreenState` controls both the weekly and score sections simultaneously. The "Show as table" / "Show chart" `TextButton` is wrapped in a `Semantics` widget with descriptive labels for screen readers. Charts themselves are wrapped with a full-sentence `Semantics.label` summary (per-day counts and total for bar chart; per-test scores and average for line chart).

### Test score chart and table (day-averaged)
`_TestScoreChart` plots one point per calendar day (the averaged accuracy from `computeLast30DaysScores`), not one point per raw test attempt. X-axis labels use real MM/DD dates via `shortDateLabel`, reusing `_WeeklyChart`'s label `TextStyle` for visual consistency between the two charts. `_ScoreTable`'s date column is labeled "Date" (not "Test #") and renders the full `isoDateKey` (yyyy-MM-dd) per row; the column's `numeric` flag is `false` since it now holds a date string, not an index.
