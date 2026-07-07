import 'package:flutter/material.dart';

import '../models/verse.dart';

/// Renders a test result's verse reference, or an italic
/// "$verseId (verse deleted)" fallback if the verse no longer exists.
class VerseReferenceLabel extends StatelessWidget {
  const VerseReferenceLabel({super.key, required this.verse, required this.verseId});

  final Verse? verse;
  final String verseId;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Text(
      verse?.reference ?? '$verseId (verse deleted)',
      style: verse == null
          ? tt.titleSmall?.copyWith(fontStyle: FontStyle.italic)
          : tt.titleSmall,
    );
  }
}
