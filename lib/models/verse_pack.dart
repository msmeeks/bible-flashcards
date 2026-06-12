import 'dart:convert';

class VersePack {
  final String id;
  final String name; // e.g. "Topical Memory System - Part 1"
  final String description;
  final List<String> verseIds; // ordered list

  const VersePack({
    required this.id,
    required this.name,
    required this.description,
    required this.verseIds,
  });

  VersePack copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? verseIds,
  }) {
    return VersePack(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      verseIds: verseIds ?? this.verseIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'verse_ids': jsonEncode(verseIds),
    };
  }

  factory VersePack.fromMap(Map<String, dynamic> map) {
    final raw = map['verse_ids'] as String? ?? '[]';
    return VersePack(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      verseIds: List<String>.from(jsonDecode(raw) as List),
    );
  }

  @override
  bool operator ==(Object other) => other is VersePack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
