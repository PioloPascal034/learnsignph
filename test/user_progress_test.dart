import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/models/lesson_progress_model.dart';
import 'package:learnsignph/services/firestore_service.dart';

void main() {
  group('user progression', () {
    test('level is based on point thresholds', () {
      expect(FirestoreService.calculateLevelFromPoints(0), 1);
      expect(FirestoreService.calculateLevelFromPoints(499), 1);
      expect(FirestoreService.calculateLevelFromPoints(500), 2);
      expect(FirestoreService.calculateLevelFromPoints(1200), 3);
    });

    test('quiz scores are percentage-based and bounded', () {
      expect(FirestoreService.calculateQuizScore(0, 4), 0);
      expect(FirestoreService.calculateQuizScore(3, 4), 75);
      expect(FirestoreService.calculateQuizScore(5, 4), 100);
      expect(FirestoreService.calculateQuizScore(1, 0), 0);
    });

    test('quiz progress keeps the best score across retries', () {
      expect(FirestoreService.bestQuizScore(75, 50), 75);
      expect(FirestoreService.bestQuizScore(75, 100), 100);
    });

    test('lesson progress round-trips incomplete scores', () {
      final progress = LessonProgressModel(
        lessonId: 'lesson',
        status: 'inProgress',
        score: 75,
      );
      final restored = LessonProgressModel.fromMap(
        progress.lessonId,
        progress.toMap(),
      );

      expect(restored.status, 'inProgress');
      expect(restored.score, 75);
    });

    test('same completed lesson does not qualify for another reward', () {
      expect(
          FirestoreService.shouldAwardLessonCompletion('inProgress'), isTrue);
      expect(FirestoreService.shouldAwardLessonCompletion(null), isTrue);
      expect(
        FirestoreService.shouldAwardLessonCompletion('completed'),
        isFalse,
      );
    });

    test('streak calculation is stable for same-day activity', () {
      final now = DateTime(2026, 11, 10, 12);
      expect(
        FirestoreService.calculateStreak(
          lastActivityDate: DateTime(2026, 11, 10, 8).toIso8601String(),
          now: now,
          currentStreak: 4,
        ),
        4,
      );
      expect(
        FirestoreService.calculateStreak(
          lastActivityDate: DateTime(2026, 11, 9, 8).toIso8601String(),
          now: now,
          currentStreak: 4,
        ),
        5,
      );
      expect(
        FirestoreService.calculateStreak(
          lastActivityDate: null,
          now: now,
          currentStreak: 0,
        ),
        1,
      );
    });

    test('badge awarding preserves existing badges and adds thresholds once',
        () {
      final badges = FirestoreService.badgesForProgress(
        currentBadges: ['rising_star'],
        points: 500,
        streak: 7,
        lessonsCompleted: 5,
      );

      expect(badges,
          containsAll(['rising_star', 'week_warrior', 'lesson_learner']));
      expect(badges.where((badge) => badge == 'rising_star'), hasLength(1));
    });
  });
}
