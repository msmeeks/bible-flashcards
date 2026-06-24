/// Turns a verse id slug like "esv_phil_4_13" or "esv_1cor_15_3_4" into a
/// human-readable reference like "Phil 4:13 (ESV)" or "1 Cor 15:3-4 (ESV)".
String formatVerseReference(String verseId) {
  final parts = verseId.split('_');
  if (parts.length < 4) return verseId;

  final translation = parts[0].toUpperCase();
  final bookSlug = parts[1];
  final chapter = parts[2];
  final verseStart = parts[3];
  final verseEnd = parts.length > 4 ? parts[4] : null;

  final bookName = _bookDisplayNames[bookSlug];
  if (bookName == null) return verseId;

  final verseRange =
      verseEnd != null ? '$verseStart-$verseEnd' : verseStart;
  return '$bookName $chapter:$verseRange ($translation)';
}

// Book slug (as used in verse ids) → short display name, e.g. "Phil".
const _bookDisplayNames = <String, String>{
  'gen': 'Gen',
  'exod': 'Exod',
  'lev': 'Lev',
  'num': 'Num',
  'deut': 'Deut',
  'josh': 'Josh',
  'judg': 'Judg',
  'ruth': 'Ruth',
  '1sam': '1 Sam',
  '2sam': '2 Sam',
  '1kgs': '1 Kgs',
  '2kgs': '2 Kgs',
  '1chr': '1 Chr',
  '2chr': '2 Chr',
  'ezra': 'Ezra',
  'neh': 'Neh',
  'esth': 'Esth',
  'job': 'Job',
  'ps': 'Ps',
  'psa': 'Ps',
  'prov': 'Prov',
  'eccl': 'Eccl',
  'song': 'Song',
  'isa': 'Isa',
  'jer': 'Jer',
  'lam': 'Lam',
  'ezek': 'Ezek',
  'dan': 'Dan',
  'hos': 'Hos',
  'joel': 'Joel',
  'amos': 'Amos',
  'obad': 'Obad',
  'jon': 'Jonah',
  'mic': 'Mic',
  'nah': 'Nah',
  'hab': 'Hab',
  'zeph': 'Zeph',
  'hag': 'Hag',
  'zech': 'Zech',
  'mal': 'Mal',
  'matt': 'Matt',
  'mark': 'Mark',
  'luke': 'Luke',
  'john': 'John',
  'acts': 'Acts',
  'rom': 'Rom',
  '1cor': '1 Cor',
  '2cor': '2 Cor',
  'gal': 'Gal',
  'eph': 'Eph',
  'phil': 'Phil',
  'col': 'Col',
  '1thess': '1 Thess',
  '2thess': '2 Thess',
  '1tim': '1 Tim',
  '2tim': '2 Tim',
  'titus': 'Titus',
  'phlm': 'Phlm',
  'heb': 'Heb',
  'jas': 'Jas',
  '1pet': '1 Pet',
  '2pet': '2 Pet',
  '1john': '1 John',
  '2john': '2 John',
  '3john': '3 John',
  'jude': 'Jude',
  'rev': 'Rev',
};
