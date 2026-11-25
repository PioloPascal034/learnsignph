import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/grammar_exercise_model.dart';
import '../models/grammar_progress_model.dart';
import '../models/sign_model.dart';
import 'firestore_service.dart';

/// Grammar-specific Firestore calls. Kept in its own file (rather than
/// bolted onto FirestoreService) since it's a distinct feature area -
/// merge the methods into FirestoreService directly if you'd rather keep
/// one service class; both work fine with the existing project structure.
class GrammarFirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static const completionReward = 100;

  static int pointsForAttempt({
    required bool wasCorrect,
    required String? previousStatus,
  }) =>
      wasCorrect && previousStatus != 'completed' ? completionReward : 0;

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
        .get();
    for (final doc in snapshot.docs) {
      if (GrammarExerciseModel.fromMap(doc.id, doc.data())
          .canPracticeSentenceOrder) {
        return doc.id;
      }
    }
    return null;
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
        .where((exercise) => exercise.canPracticeSentenceOrder)
        .toList();
  }

  /// Fetches every sign referenced by an exercise's tiles, keyed by signId,
  /// so the UI can look up word/gifUrl for each tile in one round trip.
  Future<Map<String, SignModel>> getSignsForExercise(
      GrammarExerciseModel exercise) async {
    final signIds = exercise.tiles.map((t) => t.signId).toSet().toList();
    if (signIds.isEmpty) return {};
    final signs = await FirestoreService().getSignsByIds(signIds);
    return {for (final sign in signs) sign.id: sign};
  }

  /// Records one attempt at a grammar exercise. Called every time the
  /// learner taps "Check Answer," whether correct or not - `attempts`
  /// increments regardless, `status`/`score` only improve on success.
  Future<int> recordAttempt({
    required String userId,
    required String exerciseId,
    required String mode,
    required bool wasCorrect,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != userId) {
      throw StateError('Sign in to save your exercise progress.');
    }

    // A newly created emulator account may not have a profile document yet.
    // Create it before the transaction so production rules can safely allow
    // the profile update that awards points.
    final userRef = _db.collection('users').doc(userId);
    if (!(await userRef.get()).exists) {
      await FirestoreService().createUserProfile(
        userId,
        email: authUser.email ?? 'learner@learnsign.local',
        displayName: authUser.displayName,
      );
    }

    final ref = _db
        .collection('users')
        .doc(userId)
        .collection('grammarProgress')
        .doc(exerciseId);

    return _db.runTransaction<int>((transaction) async {
      final existing = await transaction.get(ref);
      final user = await transaction.get(userRef);
      final data = existing.data();
      final prevAttempts = ((data?['attempts'] ?? 0) as num).toInt();
      final prevStatus = data?['status'] as String? ?? 'inProgress';
      final prevScore = ((data?['score'] ?? 0) as num).toDouble();
      final wasAlreadyCompleted = prevStatus == 'completed';
      final reward = pointsForAttempt(
        wasCorrect: wasCorrect,
        previousStatus: prevStatus,
      );

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

      if (reward > 0) {
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
      return reward;
    });
  }
}
