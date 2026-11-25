import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/services/grammar_firestore_service.dart';
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
    test('keeps incomplete curriculum scaffolds out of learner practice', () {
      final json = jsonDecode(File('content/phase6a_fsl_draft.json')
          .readAsStringSync()
          .replaceFirst('\uFEFF', '')) as Map;
      final exercises = (json['grammarExercises'] as List)
          .map((item) => GrammarExerciseModel.fromMap(
              item['id'] as String, Map<String, dynamic>.from(item as Map)))
          .toList();
      expect(exercises, hasLength(12));
      expect(GrammarFirestoreService.validExercises(exercises), isEmpty);
    });

    test('rejects vague prompts even when incorrectly labelled ready', () {
      final exercise = GrammarExerciseModel.fromMap('placeholder', {
        'promptText':
            'Arrange the signs in this beginner time-reference practice.',
        'contentValidationStatus': 'ready_for_learning',
        'tiles': [
          {'signId': 'one', 'correctPosition': 1},
          {'signId': 'food', 'correctPosition': 2},
        ],
      });
      expect(exercise.hasValidSentenceOrder, isTrue);
      expect(exercise.canPracticeSentenceOrder, isFalse);
    });

    test('does not silently turn matching activities into sentence questions',
        () {
      final exercise = GrammarExerciseModel.fromMap('matching', {
        'activityType': 'matching',
        'promptText': 'Match the signs.',
        'tiles': [
          {'signId': 'help', 'correctPosition': 1}
        ],
      });
      expect(exercise.canPracticeSentenceOrder, isFalse);
      expect(exercise.toMap()['activityType'], 'matching');
    });
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
