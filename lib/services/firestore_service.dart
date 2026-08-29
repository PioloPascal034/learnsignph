import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson_model.dart';
import '../models/sign_model.dart';
import '../models/lesson_progress_model.dart';

/// Single point of contact between the app and Firestore for Increment 1
/// (Core Lessons). Keeping all queries here means screens never talk to
/// Firestore directly - if the schema changes, only this file changes.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Lessons ----------

  /// Streams all lessons, optionally filtered by category.
  /// Using a Stream (not a one-time get) so the lesson list updates live
  /// if an Admin edits content while the app is open.
  Stream<List<LessonModel>> streamLessons({String? category}) {
    Query<Map<String, dynamic>> query = _db.collection('lessons');
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => LessonModel.fromMap(doc.id, doc.data()))
        .toList());
  }

  Future<LessonModel?> getLesson(String lessonId) async {
    final doc = await _db.collection('lessons').doc(lessonId).get();
    if (!doc.exists) return null;
    return LessonModel.fromMap(doc.id, doc.data()!);
  }

  // ---------- Signs ----------

  /// Fetches full SignModel objects for a list of sign IDs.
  /// Firestore has no "WHERE id IN [...]" join, so this uses whereIn,
  /// which supports up to 30 IDs per query (fine for a single lesson's
  /// sign list; batch this in chunks of 30 if a lesson ever needs more).
  Future<List<SignModel>> getSignsByIds(List<String> signIds) async {
    if (signIds.isEmpty) return [];
    final snapshot = await _db
        .collection('signs')
        .where(FieldPath.documentId, whereIn: signIds)
        .get();
    return snapshot.docs
        .map((doc) => SignModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ---------- Progress ----------

  /// Streams this user's progress for a specific lesson, if it exists.
  Stream<LessonProgressModel?> streamLessonProgress(String userId, String lessonId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId)
        .snapshots()
        .map((doc) => doc.exists ? LessonProgressModel.fromMap(lessonId, doc.data()!) : null);
  }

  /// Marks a lesson as in-progress the first time a user opens it.
  Future<void> markLessonStarted(String userId, String lessonId) async {
    final ref = _db.collection('users').doc(userId).collection('lessonProgress').doc(lessonId);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set(LessonProgressModel(
        lessonId: lessonId,
        status: 'inProgress',
        score: 0,
      ).toMap());
    }
  }

  /// Marks a lesson as completed. Called after the user finishes the
  /// lesson content (e.g., watched all sign videos and passed the quiz).
  Future<void> markLessonCompleted(String userId, String lessonId, {double score = 100}) async {
    final ref = _db.collection('users').doc(userId).collection('lessonProgress').doc(lessonId);
    await ref.set(LessonProgressModel(
      lessonId: lessonId,
      status: 'completed',
      score: score,
    ).toMap(), SetOptions(merge: true));
  }
}
