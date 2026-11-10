import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/models/grammar_exercise_model.dart';
import 'package:learnsignph/models/grammar_tile_model.dart';

void main() {
  GrammarExerciseModel createExercise(List<GrammarTileModel> tiles) {
    return GrammarExerciseModel(
      id: 'exercise',
      category: 'daily life',
      promptText: 'I need help.',
      difficulty: 'Beginner',
      tiles: tiles,
    );
  }

  group('grammar sentence-order exercises', () {
    test('orders sign IDs by their correct position', () {
      final exercise = createExercise([
        GrammarTileModel(signId: 'help', correctPosition: 2),
        GrammarTileModel(signId: 'need', correctPosition: 1),
      ]);

      expect(exercise.correctSignOrder, ['need', 'help']);
      expect(exercise.hasValidSentenceOrder, isTrue);
    });

    test('rejects duplicate sign IDs and invalid positions', () {
      expect(
        createExercise([
          GrammarTileModel(signId: 'help', correctPosition: 1),
          GrammarTileModel(signId: 'help', correctPosition: 2),
        ]).hasValidSentenceOrder,
        isFalse,
      );
      expect(
        createExercise([
          GrammarTileModel(signId: 'help', correctPosition: 1),
          GrammarTileModel(signId: 'need', correctPosition: 4),
        ]).hasValidSentenceOrder,
        isFalse,
      );
    });
  });
}
