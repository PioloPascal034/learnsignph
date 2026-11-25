import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/models/grammar_exercise_model.dart';
import 'package:learnsignph/models/grammar_tile_model.dart';
import 'package:learnsignph/models/sign_model.dart';
import 'package:learnsignph/screens/grammar/grammar_practice_screen.dart';
import 'package:learnsignph/services/grammar_firestore_service.dart';

class _GrammarService extends GrammarFirestoreService {
  var response = Completer<int>();
  int calls = 0;

  @override
  String? get currentUserId => 'test-user';

  @override
  Future<GrammarExerciseModel?> getExercise(String exerciseId) async =>
      GrammarExerciseModel(
        id: exerciseId,
        category: 'sentence_structure',
        promptText: 'I need help.',
        difficulty: 'beginner',
        imageUrl: 'https://example.invalid/unrelated-photo.jpg',
        tiles: [
          GrammarTileModel(signId: 'help', correctPosition: 1),
          GrammarTileModel(signId: 'need', correctPosition: 2),
        ],
      );

  @override
  Future<Map<String, SignModel>> getSignsForExercise(
          GrammarExerciseModel exercise) async =>
      {
        for (final word in ['Help', 'Need'])
          word.toLowerCase(): SignModel(
            id: word.toLowerCase(),
            word: word,
            gifUrl: '',
            videoUrl: '',
            category: 'test',
            difficulty: 'beginner',
          ),
      };

  @override
  Future<int> recordAttempt({
    required String userId,
    required String exerciseId,
    required String mode,
    required bool wasCorrect,
  }) {
    calls++;
    return response.future;
  }
}

Future<void> _open(WidgetTester tester, _GrammarService service) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: GrammarPracticeScreen(exerciseId: 'exercise', service: service),
  ));
  await tester.pumpAndSettle();
}

Future<void> _answer(WidgetTester tester) async {
  for (final word in ['Help', 'Need']) {
    await tester.ensureVisible(find.text(word));
    await tester.tap(find.text(word));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Check Answer'));
  await tester.tap(find.text('Check Answer'));
  await tester.pump();
}

void main() {
  testWidgets(
      'shows a meaningful target and an example before asking for order',
      (tester) async {
    await _open(tester, _GrammarService());
    expect(find.text('I need help.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.hide_image_outlined), findsNothing);
    await tester.tap(find.text('Study the example'));
    await tester.pumpAndSettle();
    expect(find.text('Example order for this exercise:'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows saving state then the actual committed reward',
      (tester) async {
    final service = _GrammarService();
    await _open(tester, service);
    await _answer(tester);
    expect(find.textContaining('+0'), findsNothing);
    expect(find.textContaining('Saving progress'), findsOneWidget);
    service.response.complete(100);
    await tester.pumpAndSettle();
    expect(find.textContaining('+100 pts earned'), findsOneWidget);
    expect(service.calls, 1);
  });

  testWidgets('explains a previously rewarded completion instead of +0 earned',
      (tester) async {
    final service = _GrammarService();
    service.response.complete(0);
    await _open(tester, service);
    await _answer(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Already completed'), findsOneWidget);
    expect(find.textContaining('+0'), findsNothing);
  });

  testWidgets('allows saving to be retried without repeating the exercise',
      (tester) async {
    final service = _GrammarService();
    await _open(tester, service);
    await _answer(tester);
    service.response.completeError(StateError('Save failed'));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving progress'), findsOneWidget);
    expect(find.textContaining('+0'), findsNothing);
    service.response = Completer<int>()..complete(100);
    await tester.ensureVisible(find.text('Retry saving progress'));
    await tester.tap(find.text('Retry saving progress'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.textContaining('+100 pts earned'), findsOneWidget);
  });
}
