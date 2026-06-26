import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/verse.dart';
import '../../widgets/esv_copyright_footer.dart';
import '../../widgets/verse_card.dart';

class ReviewShowScreen extends StatelessWidget {
  const ReviewShowScreen({super.key, required this.verses});

  final List<Verse> verses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: verses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => VerseCard(
                verse: verses[index],
                confidenceFuture:
                    DatabaseHelper().getLatestVerseAccuracy(verses[index].id),
              ),
            ),
          ),
          EsvCopyrightFooter(
            hasEsvContent: verses.any((v) => v.translation == 'ESV'),
          ),
        ],
      ),
    );
  }
}
