import '../database/database_helper.dart';
import '../models/test_result.dart';
import '../models/verse.dart';

/// Resolves the verses referenced by [results] via a single batched query,
/// keyed by verse id. Ids with no matching verse (deleted verses) are
/// simply absent from the returned map.
Future<Map<String, Verse>> resolveVersesForResults(
  List<VerseTestResult> results,
  DatabaseHelper db,
) {
  final ids = results.map((r) => r.verseId).toSet();
  return db.getVersesByIds(ids);
}
