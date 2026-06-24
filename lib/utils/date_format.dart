/// Formats a [DateTime] as a local 'yyyy-MM-dd' key, used for day-bucketing
/// and as the canonical date string shown in history tables.
String isoDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Formats a [DateTime] as an abbreviated 'MM/DD' label for chart axes.
String shortDateLabel(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
