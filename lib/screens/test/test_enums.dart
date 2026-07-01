/// Shared enums for the test flow.
enum TestMode { verseOfWeek, review }

enum TestFormat { recite, type, fillBlank }

extension TestFormatLabel on TestFormat {
  String get label => switch (this) {
        TestFormat.recite => 'Recite',
        TestFormat.type => 'Type',
        TestFormat.fillBlank => 'Fill Blanks',
      };

  /// Looks up a [TestFormat] by its persisted `.name` value, or `null` if
  /// the stored string doesn't match any current enum value (e.g. data
  /// written by a since-renamed format).
  static TestFormat? tryFromName(String name) {
    for (final format in TestFormat.values) {
      if (format.name == name) return format;
    }
    return null;
  }
}

enum PromptDirection { refToText, textToRef }

/// How many words get blanked in a fill-blank question, as a percentage of
/// candidate word count, or [random] to re-roll one of the fixed
/// percentages independently per verse.
enum BlankDensity { twenty, thirty, fifty, seventyFive, random }

extension BlankDensityLabel on BlankDensity {
  String get label => switch (this) {
        BlankDensity.twenty => '20%',
        BlankDensity.thirty => '30%',
        BlankDensity.fifty => '50%',
        BlankDensity.seventyFive => '75%',
        BlankDensity.random => 'Random',
      };

  /// The blank-density percentage this option represents. [random] has no
  /// single percentage — callers should roll one of [BlankDensity.fixedPercentages]
  /// per verse instead of reading this getter.
  int get percentage => switch (this) {
        BlankDensity.twenty => 20,
        BlankDensity.thirty => 30,
        BlankDensity.fifty => 50,
        BlankDensity.seventyFive => 75,
        BlankDensity.random =>
          throw StateError('BlankDensity.random has no single percentage'),
      };

  static const fixedPercentages = [20, 30, 50, 75];
}
