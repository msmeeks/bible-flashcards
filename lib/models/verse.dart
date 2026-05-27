class Verse {
  final String id; // unique, e.g. "esv_john_3_16"
  final String reference; // "John 3:16"
  final String text;
  final String translation; // "ESV" | "CSB" | "NLT"
  final String packId;
  final bool isMemorized;
  final bool isVerseOfWeek;
  final DateTime? memorizedAt;
  final DateTime addedAt;

  const Verse({
    required this.id,
    required this.reference,
    required this.text,
    required this.translation,
    required this.packId,
    this.isMemorized = false,
    this.isVerseOfWeek = false,
    this.memorizedAt,
    required this.addedAt,
  });

  // Use clearMemorizedAt: true to explicitly set memorizedAt back to null.
  Verse copyWith({
    String? id,
    String? reference,
    String? text,
    String? translation,
    String? packId,
    bool? isMemorized,
    bool? isVerseOfWeek,
    DateTime? memorizedAt,
    bool clearMemorizedAt = false,
    DateTime? addedAt,
  }) {
    return Verse(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      text: text ?? this.text,
      translation: translation ?? this.translation,
      packId: packId ?? this.packId,
      isMemorized: isMemorized ?? this.isMemorized,
      isVerseOfWeek: isVerseOfWeek ?? this.isVerseOfWeek,
      memorizedAt: clearMemorizedAt ? null : (memorizedAt ?? this.memorizedAt),
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'text': text,
      'translation': translation,
      'pack_id': packId,
      'is_memorized': isMemorized ? 1 : 0,
      'is_verse_of_week': isVerseOfWeek ? 1 : 0,
      'memorized_at': memorizedAt?.toIso8601String(),
      'added_at': addedAt.toIso8601String(),
    };
  }

  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      id: map['id'] as String,
      reference: map['reference'] as String,
      text: map['text'] as String,
      translation: map['translation'] as String,
      packId: map['pack_id'] as String,
      isMemorized: (map['is_memorized'] as int? ?? 0) == 1,
      isVerseOfWeek: (map['is_verse_of_week'] as int? ?? 0) == 1,
      memorizedAt: map['memorized_at'] != null
          ? DateTime.parse(map['memorized_at'] as String)
          : null,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) => other is Verse && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
