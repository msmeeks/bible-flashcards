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
