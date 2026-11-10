import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/models/lesson_activity_model.dart';
import 'package:learnsignph/models/lesson_activity_progress_model.dart';
import 'package:learnsignph/services/lesson_activity_engine.dart';

void main() {
  group('lesson activity parsing and validation', () {
    test('parses identification activities from the proposed schema', () {
      final activity = LessonActivityModel.fromMap('a1', {
        'type': 'identification',
        'instruction': 'Watch the sign.',
        'prompt': 'What does this mean?',
        'mediaUrl': 'https://example.test/sign.gif',
        'mediaType': 'gif',
        'options': ['Hello', 'Goodbye'],
        'correctAnswer': 'Hello',
      });

      expect(activity.id, 'a1');
      expect(activity.type, LessonActivityType.identification);
      expect(activity.isValid, isTrue);
    });

    test('invalid activities are filtered without crashing the lesson', () {
      final invalid = LessonActivityModel.fromMap('bad', {
        'type': 'conversation',
        'prompt': 'Choose a response',
        'options': ['Hello'],
        'correctAnswer': 'Missing',
      });

      expect(invalid.isValid, isFalse);
      expect(LessonActivityEngine.validActivities([invalid]), isEmpty);
    });

    test('legacy sign activity remains valid without Firestore activities', () {
      final activity = LessonActivityModel.fromSign(
        id: 'legacy',
        word: 'Hello',
        mediaUrl: '',
        mediaType: 'gif',
        distractors: ['Goodbye', 'Thank you'],
      );

      expect(activity.isValid, isTrue);
      expect(activity.correctAnswer, 'Hello');
    });
  });

  group('lesson activity evaluation', () {
    test('evaluates identification and conversation answers', () {
      final activity = LessonActivityModel.fromMap('choice', {
        'type': 'conversation',
        'prompt': 'How do you greet someone?',
        'options': ['Hello', 'Goodbye'],
        'correctAnswer': 'Hello',
      });

      expect(
        LessonActivityEngine.isCorrect(activity, answer: 'Hello'),
        isTrue,
      );
      expect(
        LessonActivityEngine.isCorrect(activity, answer: 'Goodbye'),
        isFalse,
      );
    });

    test('evaluates matching and ordering activities', () {
      final matching = LessonActivityModel.fromMap('matching', {
        'type': 'matching',
        'pairs': [
          {'left': 'Hello', 'right': 'greeting'},
          {'left': 'Doctor', 'right': 'health'},
        ],
      });
      final ordering = LessonActivityModel.fromMap('ordering', {
        'type': 'ordering',
        'items': ['Help', 'Need'],
        'correctOrder': ['Need', 'Help'],
      });

      expect(
        LessonActivityEngine.isCorrect(
          matching,
          matching: {'Hello': 'greeting', 'Doctor': 'health'},
        ),
        isTrue,
      );
      expect(
        LessonActivityEngine.isCorrect(
          ordering,
          orderedItems: ['Need', 'Help'],
        ),
        isTrue,
      );
    });

    test('calculates bounded percentage scores', () {
      expect(LessonActivityEngine.score(correct: 0, total: 4), 0);
      expect(LessonActivityEngine.score(correct: 3, total: 4), 75);
      expect(LessonActivityEngine.score(correct: 8, total: 4), 100);
    });
  });

  test('activity progress serializes attempts, best score, and completion', () {
    const progress = LessonActivityProgressModel(
      activityId: 'activity_1',
      attempts: 2,
      bestScore: 100,
      status: 'completed',
    );
    final restored = LessonActivityProgressModel.fromMap(
      progress.activityId,
      progress.toMap(),
    );

    expect(restored.attempts, 2);
    expect(restored.bestScore, 100);
    expect(restored.status, 'completed');
  });
}
