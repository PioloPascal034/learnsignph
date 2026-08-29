import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grammar_exercise_model.dart';
import '../models/grammar_progress_model.dart';
import '../models/sign_model.dart';

/// Grammar-specific Firestore calls. Kept in its own file (rather than
/// bolted onto FirestoreService) since it's a distinct feature area -
/// merge the methods into FirestoreService directly if you'd rather keep
/// one service class; both work fine with the existing project structure.
class GrammarFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches a single grammar exercise by ID (used for in-lesson practice,
  /// where the lesson detail screen already knows which exercise to load).
  Future<GrammarExerciseModel?> getExercise(String exerciseId) async {
    final doc = await _db.collection('grammarExercises').doc(exerciseId).get();
    if (!doc.exists) return null;
    return GrammarExerciseModel.fromMap(doc.id, doc.data()!);
  }

  /// Fetches every sign referenced by an exercise's tiles, keyed by signId,
  /// so the UI can look up word/gifUrl for each tile in one round trip.
  Future<Map<String, SignModel>> getSignsForExercise(GrammarExerciseModel exercise) async {
    final signIds = exercise.tiles.map((t) => t.signId).toSet().toList();
    if (signIds.isEmpty) return {};
    final snapshot = await _db
        .collection('signs')
        .where(FieldPath.documentId, whereIn: signIds)
        .get();
    return {
      for (final doc in snapshot.docs) doc.id: SignModel.fromMap(doc.id, doc.data()),
    };
  }

  /// Records one attempt at a grammar exercise. Called every time the
  /// learner taps "Check Answer," whether correct or not - `attempts`
  /// increments regardless, `status`/`score` only improve on success.
  Future<void> recordAttempt({
    required String userId,
    required String exerciseId,
    required String mode,
    required bool wasCorrect,
  }) async {
    final ref = _db
        .collection('users')
        .doc(userId)
        .collection('grammarProgress')
        .doc(exerciseId);

    final existing = await ref.get();
    final prevAttempts = existing.exists ? (existing.data()?['attempts'] ?? 0) as int : 0;
    final prevStatus = existing.exists ? (existing.data()?['status'] ?? 'inProgress') : 'inProgress';

    final model = GrammarProgressModel(
      exerciseId: exerciseId,
      mode: mode,
      status: wasCorrect ? 'completed' : (prevStatus == 'completed' ? 'completed' : 'inProgress'),
      score: wasCorrect ? 100 : 0,
      attempts: prevAttempts + 1,
    );

    await ref.set(model.toMap(), SetOptions(merge: true));
  }
}
