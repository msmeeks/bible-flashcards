import 'book_name_variants.dart' show bookDisplayNames, bookNameToUsfm;
import 'scoring.dart' show normalizeReferenceInput, referenceSplitPattern;

/// Why [ReferenceNormalizationResult.isSuccess] is false.
enum ReferenceNormalizationFailure {
  /// The string isn't shaped like "Book Chapter:Verse[-End]" at all.
  invalidFormat,

  /// The book-name span didn't resolve against the built-in table or the
  /// caller-supplied custom variants.
  unresolvedBook,
}

/// Outcome of [normalizeReferenceForSave]: either a canonical reference
/// string, or a [failure] reason the caller can use to drive UI state.
class ReferenceNormalizationResult {
  const ReferenceNormalizationResult.success(this.reference)
      : failure = null;
  const ReferenceNormalizationResult.failure(ReferenceNormalizationFailure f)
      : reference = null,
        failure = f;

  final String? reference;
  final ReferenceNormalizationFailure? failure;

  bool get isSuccess => reference != null;
}

/// Normalizes a typed verse reference to the canonical
/// "Book Chapter:Verse[-End]" save form: full book name (resolved against
/// the built-in variant table plus [customVariants]) and standardized
/// separators/ranges.
ReferenceNormalizationResult normalizeReferenceForSave(
  String raw, {
  Map<String, String> customVariants = const {},
}) {
  final match = referenceSplitPattern.firstMatch(
    normalizeReferenceInput(raw.trim()),
  );
  if (match == null) {
    return const ReferenceNormalizationResult.failure(
      ReferenceNormalizationFailure.invalidFormat,
    );
  }

  final bookSpan = match.group(1)!;
  final chapterVerse = match.group(2)!;
  final usfm = bookNameToUsfm(bookSpan, customVariants: customVariants);
  if (usfm == null) {
    return const ReferenceNormalizationResult.failure(
      ReferenceNormalizationFailure.unresolvedBook,
    );
  }

  return ReferenceNormalizationResult.success(
    '${bookDisplayNames[usfm]} $chapterVerse',
  );
}
