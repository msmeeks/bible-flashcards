import 'package:bible_flashcards/models/verse.dart';

Verse makeVerse(
  String id, {
  String? reference,
  String? text,
  String translation = 'ESV',
  String packId = 'pack',
  bool isMemorized = true,
  bool isVerseOfWeek = false,
  DateTime? addedAt,
}) {
  return Verse(
    id: id,
    reference: reference ?? 'Ref $id',
    text: text ?? 'Text $id',
    translation: translation,
    packId: packId,
    isMemorized: isMemorized,
    isVerseOfWeek: isVerseOfWeek,
    addedAt: addedAt ?? DateTime(2024, 1, 1),
  );
}
