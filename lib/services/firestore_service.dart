import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson_model.dart';
import '../models/lesson_activity_progress_model.dart';
import '../models/sign_model.dart';
import '../models/lesson_progress_model.dart';

/// Single point of contact between the app and Firestore for Increment 1
/// (Core Lessons). Keeping all queries here means screens never talk to
/// Firestore directly - if the schema changes, only this file changes.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static int calculateLevelFromPoints(int points) {
    if (points <= 0) return 1;
    return (points ~/ 500) + 1;
  }

  static bool shouldAwardLessonCompletion(String? previousStatus) {
    return previousStatus != 'completed';
  }

  static double calculateQuizScore(int correctAnswers, int totalQuestions) {
    if (totalQuestions <= 0) return 0;
    final safeCorrect = correctAnswers.clamp(0, totalQuestions);
    return (safeCorrect / totalQuestions) * 100;
  }

  static double bestQuizScore(double previousScore, double attemptScore) {
    return previousScore > attemptScore ? previousScore : attemptScore;
  }

  static int calculateStreak({
    required String? lastActivityDate,
    required DateTime now,
    required int currentStreak,
  }) {
    final lastActivity =
        lastActivityDate == null ? null : DateTime.tryParse(lastActivityDate);
    if (lastActivity == null) return 1;

    final daysDiff = now.difference(lastActivity).inDays;
    if (daysDiff == 0) return currentStreak;
    if (daysDiff == 1) return currentStreak + 1;
    return 1;
  }

  static List<String> badgesForProgress({
    required List<String> currentBadges,
    required int points,
    required int streak,
    required int lessonsCompleted,
  }) {
    final badges = [...currentBadges];
    final thresholds = <String, bool>{
      'rising_star': points >= 500,
      'scholar': points >= 1000,
      'week_warrior': streak >= 7,
      'month_master': streak >= 30,
      'lesson_learner': lessonsCompleted >= 5,
      'achievement_hunter': lessonsCompleted >= 10,
    };
    for (final entry in thresholds.entries) {
      if (entry.value && !badges.contains(entry.key)) badges.add(entry.key);
    }
    return badges;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(
      String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  Future<void> createUserProfile(
    String userId, {
    required String email,
    String? displayName,
  }) async {
    final ref = _db.collection('users').doc(userId);
    final snapshot = await ref.get();
    final safeDisplayName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : email.split('@').first;

    final payload = {
      'uid': userId,
      'email': email,
      'displayName': safeDisplayName,
      'age': null,
      'bio': '',
      'photoUrl': null,
      'points': snapshot.data()?['points'] ?? 0,
      'level': snapshot.data()?['level'] ?? 1,
      'streak': snapshot.data()?['streak'] ?? 0,
      'lastActivityDate': DateTime.now().toIso8601String(),
      'badges': snapshot.data()?['badges'] ?? [],
      'lessonsCompleted': snapshot.data()?['lessonsCompleted'] ?? 0,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (!snapshot.exists) {
      payload['createdAt'] = DateTime.now().toIso8601String();
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> addUserPoints(String userId, int pointsToAdd) async {
    if (pointsToAdd == 0) return;

    final ref = _db.collection('users').doc(userId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final currentPoints = (snapshot.data()?['points'] ?? 0) as num;
      final newPoints = (currentPoints + pointsToAdd).toInt();
      transaction.set(
          ref,
          {
            'points': newPoints,
            'level': calculateLevelFromPoints(newPoints),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true));
    });
  }

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

  String newLessonId() => _db.collection('lessons').doc().id;

  Future<void> saveLesson(String lessonId, Map<String, dynamic> data) {
    return _db.collection('lessons').doc(lessonId).set(data);
  }

  Future<LessonModel?> getLesson(String lessonId) async {
    final doc = await _db.collection('lessons').doc(lessonId).get();
    if (!doc.exists) return null;
    return LessonModel.fromMap(doc.id, doc.data()!);
  }

  // ---------- Signs ----------

  Stream<List<SignModel>> streamSigns() {
    return _db.collection('signs').orderBy('word').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => SignModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  String newSignId() => _db.collection('signs').doc().id;

  Future<void> saveSign(String signId, Map<String, dynamic> data) {
    return _db.collection('signs').doc(signId).set(data);
  }

  Future<void> updateSignGifUrl(String signId, String gifUrl) {
    return _db.collection('signs').doc(signId).update({'gifUrl': gifUrl});
  }

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

  /// Fetches this user's progress for a specific lesson, if it exists.
  Future<LessonProgressModel?> getLessonProgress(
      String userId, String lessonId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId)
        .get();
    return doc.exists
        ? LessonProgressModel.fromMap(lessonId, doc.data()!)
        : null;
  }

  Future<Map<String, LessonActivityProgressModel>> getLessonActivityProgress(
      String userId, String lessonId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId)
        .collection('activityProgress')
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: LessonActivityProgressModel.fromMap(doc.id, doc.data()),
    };
  }

  Future<void> recordLessonActivityResult({
    required String userId,
    required String lessonId,
    required String activityId,
    required double score,
    required bool passed,
  }) async {
    final lessonProgressRef = _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId);
    final activityRef =
        lessonProgressRef.collection('activityProgress').doc(activityId);

    await _db.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityRef);
      final lessonSnapshot = await transaction.get(lessonProgressRef);
      final previous = activitySnapshot.data();
      final previousScore = (previous?['bestScore'] as num?)?.toDouble() ?? 0;
      final previousStatus = previous?['status']?.toString() ?? 'inProgress';
      final bestScore = previousScore > score ? previousScore : score;
      final now = DateTime.now();

      transaction.set(
        activityRef,
        LessonActivityProgressModel(
          activityId: activityId,
          attempts: ((previous?['attempts'] as num?)?.toInt() ?? 0) + 1,
          bestScore: bestScore,
          status: previousStatus == 'completed' || passed
              ? 'completed'
              : 'inProgress',
          updatedAt: now,
        ).toMap(now: now),
        SetOptions(merge: true),
      );

      final parent = lessonSnapshot.data() ?? <String, dynamic>{};
      final parentBest = (parent['bestActivityScore'] as num?)?.toDouble() ?? 0;
      transaction.set(
        lessonProgressRef,
        {
          'status': parent['status'] ?? 'inProgress',
          'score': parent['score'] ?? 0,
          'bestActivityScore': parentBest > bestScore ? parentBest : bestScore,
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Streams this user's progress for a specific lesson, if it exists.
  Stream<LessonProgressModel?> streamLessonProgress(
      String userId, String lessonId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId)
        .snapshots()
        .map((doc) => doc.exists
            ? LessonProgressModel.fromMap(lessonId, doc.data()!)
            : null);
  }

  /// Marks a lesson as in-progress the first time a user opens it.
  Future<void> markLessonStarted(String userId, String lessonId) async {
    final ref = _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId);
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
  /// Also awards a small XP reward so the dashboard and profile stay in sync.
  /// Updates streak if appropriate and awards badges.
  Future<void> markLessonCompleted(
    String userId,
    String lessonId, {
    double score = 100,
    int pointReward = 100,
  }) async {
    return recordLessonQuizResult(
      userId: userId,
      lessonId: lessonId,
      score: score,
      passed: true,
      pointReward: pointReward,
    );
  }

  Future<void> recordLessonQuizResult({
    required String userId,
    required String lessonId,
    required double score,
    required bool passed,
    int pointReward = 100,
  }) async {
    final progressRef = _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .doc(lessonId);
    final userRef = _db.collection('users').doc(userId);
    final now = DateTime.now();
    final timestamp = now.toIso8601String();

    await _db.runTransaction((transaction) async {
      final progressSnapshot = await transaction.get(progressRef);
      final userSnapshot = await transaction.get(userRef);
      final progressData = progressSnapshot.data();
      final previousStatus = progressData?['status'] as String?;
      final previousScore = ((progressData?['score'] ?? 0) as num).toDouble();
      final shouldAward = passed && shouldAwardLessonCompletion(previousStatus);
      final bestScore = bestQuizScore(previousScore, score);
      final nextStatus =
          previousStatus == 'completed' || passed ? 'completed' : 'inProgress';

      transaction.set(
        progressRef,
        {
          'status': nextStatus,
          'score': bestScore,
          'updatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      if (!shouldAward) return;

      final data = userSnapshot.data() ?? <String, dynamic>{};
      final currentPoints = ((data['points'] ?? 0) as num).toInt();
      final newPoints = currentPoints + pointReward;
      final currentStreak = ((data['streak'] ?? 0) as num).toInt();
      final lessonsCompleted =
          ((data['lessonsCompleted'] ?? 0) as num).toInt() + 1;
      final newStreak = calculateStreak(
        lastActivityDate: data['lastActivityDate'] as String?,
        now: now,
        currentStreak: currentStreak,
      );
      final currentBadges = List<String>.from(data['badges'] ?? const []);
      final newBadges = badgesForProgress(
        currentBadges: currentBadges,
        points: newPoints,
        streak: newStreak,
        lessonsCompleted: lessonsCompleted,
      );

      transaction.set(
          userRef,
          {
            'points': newPoints,
            'level': calculateLevelFromPoints(newPoints),
            'streak': newStreak,
            'lessonsCompleted': lessonsCompleted,
            'lastActivityDate': timestamp,
            'badges': newBadges,
            'updatedAt': timestamp,
          },
          SetOptions(merge: true));
    });
  }

  /// Gets badge details for display
  static Map<String, Map<String, String>> getBadgeDetails() {
    return {
      'rising_star': {
        'title': 'Rising Star ⭐',
        'description': 'Earned 500 points',
      },
      'scholar': {
        'title': 'Scholar 📚',
        'description': 'Earned 1000 points',
      },
      'week_warrior': {
        'title': 'Week Warrior 🔥',
        'description': '7 day streak',
      },
      'month_master': {
        'title': 'Month Master 👑',
        'description': '30 day streak',
      },
      'lesson_learner': {
        'title': 'Lesson Learner 🎓',
        'description': 'Completed 5 lessons',
      },
      'achievement_hunter': {
        'title': 'Achievement Hunter 🎯',
        'description': 'Completed 10 lessons',
      },
    };
  }

  // ---------- Update User Profile ----------

  /// Updates user's display name and password
  Future<void> updateUserProfile(
    String userId, {
    String? displayName,
    String? currentPassword,
    String? newPassword,
    int? age,
    String? bio,
    String? photoUrl,
  }) async {
    final ref = _db.collection('users').doc(userId);
    final updateMap = <String, dynamic>{};

    if (displayName != null && displayName.isNotEmpty) {
      updateMap['displayName'] = displayName;
    }
    if (age != null) {
      updateMap['age'] = age;
    }
    if (bio != null) {
      updateMap['bio'] = bio;
    }
    if (photoUrl != null) {
      updateMap['photoUrl'] = photoUrl;
    }

    if (updateMap.isNotEmpty) {
      updateMap['updatedAt'] = DateTime.now().toIso8601String();
      await ref.set(updateMap, SetOptions(merge: true));
    }

    // Note: Password update is handled by Firebase Auth, not Firestore
    // See profile_screen.dart for password update implementation
  }

  /// Gets all lessons completed by the user
  Future<List<LessonModel>> getUserCompletedLessons(String userId) async {
    final progressDocs = await _db
        .collection('users')
        .doc(userId)
        .collection('lessonProgress')
        .where('status', isEqualTo: 'completed')
        .get();

    final lessonIds = progressDocs.docs.map((doc) => doc.id).toList();
    if (lessonIds.isEmpty) return [];

    final lessons = await Future.wait(
      lessonIds.map((id) => getLesson(id)),
    );
    return lessons.whereType<LessonModel>().toList();
  }

  /// Gets all signs learned by the user (from completed lessons)
  Future<List<SignModel>> getUserLearnedSigns(String userId) async {
    final completedLessons = await getUserCompletedLessons(userId);
    final signIds = <String>{};

    for (final lesson in completedLessons) {
      signIds.addAll(lesson.signIds);
    }

    if (signIds.isEmpty) return [];
    return getSignsByIds(signIds.toList());
  }

  /// Streams user's current streak info
  Stream<Map<String, dynamic>> streamStreakInfo(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return {
        'streak': (data['streak'] as num?)?.toInt() ?? 0,
        'lastActivityDate': data['lastActivityDate'] as String?,
      };
    });
  }
}
