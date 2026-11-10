import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grammar_exercise_model.dart';
import '../models/grammar_progress_model.dart';
import '../models/sign_model.dart';
import 'firestore_service.dart';

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

  Future<String?> getExerciseIdForLesson(String lessonId) async {
    final snapshot = await _db
        .collection('grammarExercises')
        .where('lessonId', isEqualTo: lessonId)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.id;
  }

  Stream<List<GrammarExerciseModel>> streamExercises() {
    return _db.collection('grammarExercises').snapshots().map(
          (snapshot) => validExercises(snapshot.docs
              .map((doc) => GrammarExerciseModel.fromMap(doc.id, doc.data()))),
        );
  }

  static List<GrammarExerciseModel> validExercises(
      Iterable<GrammarExerciseModel> exercises) {
    return exercises
        .where((exercise) => exercise.hasValidSentenceOrder)
        .toList();
  }

  /// Fetches every sign referenced by an exercise's tiles, keyed by signId,
  /// so the UI can look up word/gifUrl for each tile in one round trip.
  Future<Map<String, SignModel>> getSignsForExercise(
      GrammarExerciseModel exercise) async {
    final signIds = exercise.tiles.map((t) => t.signId).toSet().toList();
    if (signIds.isEmpty) return {};
    final snapshot = await _db
        .collection('signs')
        .where(FieldPath.documentId, whereIn: signIds)
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: SignModel.fromMap(doc.id, doc.data()),
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

    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      final user = await transaction.get(userRef);
      final data = existing.data();
      final prevAttempts = ((data?['attempts'] ?? 0) as num).toInt();
      final prevStatus = data?['status'] as String? ?? 'inProgress';
      final prevScore = ((data?['score'] ?? 0) as num).toDouble();
      final wasAlreadyCompleted = prevStatus == 'completed';

      transaction.set(
        ref,
        GrammarProgressModel(
          exerciseId: exerciseId,
          mode: mode,
          status:
              wasCorrect || wasAlreadyCompleted ? 'completed' : 'inProgress',
          score: wasCorrect ? 100.0 : prevScore,
          attempts: prevAttempts + 1,
        ).toMap(),
        SetOptions(merge: true),
      );

      if (wasCorrect && !wasAlreadyCompleted) {
        final reward = mode == 'test' ? 60 : 40;
        final currentPoints = ((user.data()?['points'] ?? 0) as num).toInt();
        final newPoints = currentPoints + reward;
        transaction.set(
          userRef,
          {
            'points': newPoints,
            'level': FirestoreService.calculateLevelFromPoints(newPoints),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }
}
