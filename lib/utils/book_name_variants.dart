/// Shared book-name-variant table used by both reference parsing
/// (lookup/import, see `BibleLookupService`) and reference-answer scoring
/// (see `computeReferenceScore` in `scoring.dart`).
///
/// Keys are normalized (lowercase, spaces/dots stripped). This is the single
/// source of truth for book-name variants — do not duplicate it.
library;

/// Maximum length of a single variant string. Anything longer is rejected
/// before it ever reaches matching code, to bound matching cost.
const int maxVariantLength = 60;

/// Maximum number of custom variants a user may store in total.
const int maxCustomVariants = 200;

/// USFM code → canonical display name, in canonical (Protestant) book order.
const Map<String, String> bookDisplayNames = <String, String>{
  'GEN': 'Genesis', 'EXO': 'Exodus', 'LEV': 'Leviticus', 'NUM': 'Numbers',
  'DEU': 'Deuteronomy', 'JOS': 'Joshua', 'JDG': 'Judges', 'RUT': 'Ruth',
  '1SA': '1 Samuel', '2SA': '2 Samuel', '1KI': '1 Kings', '2KI': '2 Kings',
  '1CH': '1 Chronicles', '2CH': '2 Chronicles', 'EZR': 'Ezra', 'NEH': 'Nehemiah',
  'EST': 'Esther', 'JOB': 'Job', 'PSA': 'Psalms', 'PRO': 'Proverbs',
  'ECC': 'Ecclesiastes', 'SNG': 'Song of Solomon', 'ISA': 'Isaiah',
  'JER': 'Jeremiah', 'LAM': 'Lamentations', 'EZK': 'Ezekiel', 'DAN': 'Daniel',
  'HOS': 'Hosea', 'JOL': 'Joel', 'AMO': 'Amos', 'OBA': 'Obadiah',
  'JON': 'Jonah', 'MIC': 'Micah', 'NAH': 'Nahum', 'HAB': 'Habakkuk',
  'ZEP': 'Zephaniah', 'HAG': 'Haggai', 'ZEC': 'Zechariah', 'MAL': 'Malachi',
  'MAT': 'Matthew', 'MRK': 'Mark', 'LUK': 'Luke', 'JHN': 'John',
  'ACT': 'Acts', 'ROM': 'Romans', '1CO': '1 Corinthians', '2CO': '2 Corinthians',
  'GAL': 'Galatians', 'EPH': 'Ephesians', 'PHP': 'Philippians', 'COL': 'Colossians',
  '1TH': '1 Thessalonians', '2TH': '2 Thessalonians', '1TI': '1 Timothy',
  '2TI': '2 Timothy', 'TIT': 'Titus', 'PHM': 'Philemon', 'HEB': 'Hebrews',
  'JAS': 'James', '1PE': '1 Peter', '2PE': '2 Peter', '1JN': '1 John',
  '2JN': '2 John', '3JN': '3 John', 'JUD': 'Jude', 'REV': 'Revelation',
};

/// Built-in book-name variants (lowercase, spaces/dots stripped) → USFM code.
///
/// Extends the original short-abbreviation table (moved here from
/// `BibleLookupService`) with longhand forms ("Gospel of Mark", "Book of
/// Acts") and spoken number-word forms for numbered books ("first peter",
/// "one peter", "1st peter").
const Map<String, String> builtInBookNameVariants = <String, String>{
  // Old Testament
  'genesis': 'GEN', 'gen': 'GEN',
  'exodus': 'EXO', 'exod': 'EXO', 'exo': 'EXO',
  'leviticus': 'LEV', 'lev': 'LEV',
  'numbers': 'NUM', 'num': 'NUM',
  'deuteronomy': 'DEU', 'deut': 'DEU', 'deu': 'DEU',
  'joshua': 'JOS', 'josh': 'JOS', 'jos': 'JOS', 'thebookofjoshua': 'JOS',
  'judges': 'JDG', 'judg': 'JDG', 'jdg': 'JDG', 'thebookofjudges': 'JDG',
  'ruth': 'RUT', 'rut': 'RUT', 'thebookofruth': 'RUT',
  '1samuel': '1SA', '1sam': '1SA', '1sa': '1SA', 'firstsamuel': '1SA', 'onesamuel': '1SA', '1stsamuel': '1SA',
  '2samuel': '2SA', '2sam': '2SA', '2sa': '2SA', 'secondsamuel': '2SA', 'twosamuel': '2SA', '2ndsamuel': '2SA',
  '1kings': '1KI', '1kgs': '1KI', '1ki': '1KI', 'firstkings': '1KI', 'onekings': '1KI', '1stkings': '1KI',
  '2kings': '2KI', '2kgs': '2KI', '2ki': '2KI', 'secondkings': '2KI', 'twokings': '2KI', '2ndkings': '2KI',
  '1chronicles': '1CH', '1chron': '1CH', '1chr': '1CH', '1ch': '1CH', 'firstchronicles': '1CH', 'onechronicles': '1CH', '1stchronicles': '1CH',
  '2chronicles': '2CH', '2chron': '2CH', '2chr': '2CH', '2ch': '2CH', 'secondchronicles': '2CH', 'twochronicles': '2CH', '2ndchronicles': '2CH',
  'ezra': 'EZR', 'ezr': 'EZR',
  'nehemiah': 'NEH', 'neh': 'NEH',
  'esther': 'EST', 'esth': 'EST', 'est': 'EST',
  'job': 'JOB',
  'psalm': 'PSA', 'psalms': 'PSA', 'psa': 'PSA', 'ps': 'PSA', 'thebookofpsalms': 'PSA',
  'proverbs': 'PRO', 'prov': 'PRO', 'pro': 'PRO',
  'ecclesiastes': 'ECC', 'eccl': 'ECC', 'ecc': 'ECC',
  'songofsolomon': 'SNG', 'songofsongs': 'SNG', 'song': 'SNG', 'sos': 'SNG', 'sng': 'SNG',
  'isaiah': 'ISA', 'isa': 'ISA', 'thebookofisaiah': 'ISA',
  'jeremiah': 'JER', 'jer': 'JER', 'thebookofjeremiah': 'JER',
  'lamentations': 'LAM', 'lam': 'LAM',
  'ezekiel': 'EZK', 'ezek': 'EZK', 'eze': 'EZK', 'ezk': 'EZK',
  'daniel': 'DAN', 'dan': 'DAN', 'thebookofdaniel': 'DAN',
  'hosea': 'HOS', 'hos': 'HOS',
  'joel': 'JOL', 'joe': 'JOL', 'jol': 'JOL',
  'amos': 'AMO', 'amo': 'AMO',
  'obadiah': 'OBA', 'obad': 'OBA', 'oba': 'OBA',
  'jonah': 'JON', 'jon': 'JON',
  'micah': 'MIC', 'mic': 'MIC',
  'nahum': 'NAH', 'nah': 'NAH',
  'habakkuk': 'HAB', 'hab': 'HAB',
  'zephaniah': 'ZEP', 'zeph': 'ZEP', 'zep': 'ZEP',
  'haggai': 'HAG', 'hag': 'HAG',
  'zechariah': 'ZEC', 'zech': 'ZEC', 'zec': 'ZEC',
  'malachi': 'MAL', 'mal': 'MAL',
  // New Testament
  'matthew': 'MAT', 'matt': 'MAT', 'mat': 'MAT', 'thegospelofmatthew': 'MAT', 'thegospelaccordingtomatthew': 'MAT', 'stmatthew': 'MAT',
  'mark': 'MRK', 'mar': 'MRK', 'mrk': 'MRK', 'thegospelofmark': 'MRK', 'thegospelaccordingtomark': 'MRK', 'stmark': 'MRK',
  'luke': 'LUK', 'luk': 'LUK', 'thegospelofluke': 'LUK', 'thegospelaccordingtoluke': 'LUK', 'stluke': 'LUK',
  'john': 'JHN', 'joh': 'JHN', 'jhn': 'JHN', 'thegospelofjohn': 'JHN', 'thegospelaccordingtojohn': 'JHN', 'stjohn': 'JHN',
  'acts': 'ACT', 'act': 'ACT', 'theactsoftheapostles': 'ACT', 'thebookofacts': 'ACT',
  'romans': 'ROM', 'rom': 'ROM',
  '1corinthians': '1CO', '1cor': '1CO', '1co': '1CO', 'firstcorinthians': '1CO', 'onecorinthians': '1CO', '1stcorinthians': '1CO',
  '2corinthians': '2CO', '2cor': '2CO', '2co': '2CO', 'secondcorinthians': '2CO', 'twocorinthians': '2CO', '2ndcorinthians': '2CO',
  'galatians': 'GAL', 'gal': 'GAL',
  'ephesians': 'EPH', 'eph': 'EPH',
  'philippians': 'PHP', 'phil': 'PHP', 'php': 'PHP',
  'colossians': 'COL', 'col': 'COL',
  '1thessalonians': '1TH', '1thess': '1TH', '1th': '1TH', 'firstthessalonians': '1TH', 'onethessalonians': '1TH', '1stthessalonians': '1TH',
  '2thessalonians': '2TH', '2thess': '2TH', '2th': '2TH', 'secondthessalonians': '2TH', 'twothessalonians': '2TH', '2ndthessalonians': '2TH',
  '1timothy': '1TI', '1tim': '1TI', '1ti': '1TI', 'firsttimothy': '1TI', 'onetimothy': '1TI', '1sttimothy': '1TI',
  '2timothy': '2TI', '2tim': '2TI', '2ti': '2TI', 'secondtimothy': '2TI', 'twotimothy': '2TI', '2ndtimothy': '2TI',
  'titus': 'TIT', 'tit': 'TIT',
  'philemon': 'PHM', 'phlm': 'PHM', 'phm': 'PHM',
  'hebrews': 'HEB', 'heb': 'HEB',
  'james': 'JAS', 'jas': 'JAS',
  '1peter': '1PE', '1pet': '1PE', '1pe': '1PE', '1pt': '1PE', 'firstpeter': '1PE', 'onepeter': '1PE', '1stpeter': '1PE',
  '2peter': '2PE', '2pet': '2PE', '2pe': '2PE', '2pt': '2PE', 'secondpeter': '2PE', 'twopeter': '2PE', '2ndpeter': '2PE',
  '1john': '1JN', '1jn': '1JN', 'firstjohn': '1JN', 'onejohn': '1JN', '1stjohn': '1JN',
  '2john': '2JN', '2jn': '2JN', 'secondjohn': '2JN', 'twojohn': '2JN', '2ndjohn': '2JN',
  '3john': '3JN', '3jn': '3JN', 'thirdjohn': '3JN', 'threejohn': '3JN', '3rdjohn': '3JN',
  'jude': 'JUD', 'jud': 'JUD',
  'revelation': 'REV', 'rev': 'REV', 'apoc': 'REV', 'thebookofrevelation': 'REV', 'revelations': 'REV',
};

/// Normalizes a book-name string for variant lookup: lowercase, spaces and
/// dots stripped. Mirrors the normalization already used for the built-in
/// table and `BibleLookupService`'s parsing.
String normalizeBookNameKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[\s.]+'), '');

/// Resolves a (possibly variant) book name to its canonical USFM code,
/// checking [customVariants] (already-normalized keys) before the built-in
/// table. Returns `null` if the name is unrecognized.
String? bookNameToUsfm(
  String name, {
  Map<String, String> customVariants = const {},
}) {
  final key = normalizeBookNameKey(name);
  return customVariants[key] ?? builtInBookNameVariants[key];
}
