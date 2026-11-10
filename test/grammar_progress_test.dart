import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/models/grammar_exercise_model.dart';
import 'package:learnsignph/models/grammar_progress_model.dart';
import 'package:learnsignph/models/grammar_tile_model.dart';
import 'package:learnsignph/services/grammar_firestore_service.dart';

GrammarExerciseModel _exercise({bool valid = true}) {
  return GrammarExerciseModel(
    id: valid ? 'valid' : 'invalid',
    category: 'practice',
    promptText: valid ? 'Need help' : '',
    difficulty: 'beginner',
    tiles: valid
        ? [
            GrammarTileModel(signId: 'need', correctPosition: 1),
            GrammarTileModel(signId: 'help', correctPosition: 2),
          ]
        : [],
  );
}

void main() {
  test('grammar progress round-trips attempts and completion state', () {
    final progress = GrammarProgressModel(
      exerciseId: 'exercise',
      mode: 'lesson',
      status: 'completed',
      score: 100,
      attempts: 3,
    );

    final restored = GrammarProgressModel.fromMap(
      progress.exerciseId,
      progress.toMap(),
    );

    expect(restored.status, 'completed');
    expect(restored.score, 100);
    expect(restored.attempts, 3);
  });

  test('invalid or empty exercises are excluded from the hub list', () {
    final exercises = GrammarFirestoreService.validExercises([
      _exercise(),
      _exercise(valid: false),
    ]);

    expect(exercises.map((exercise) => exercise.id), ['valid']);
    expect(GrammarFirestoreService.validExercises(const []).isEmpty, isTrue);
  });
}
