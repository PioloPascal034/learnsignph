import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/screens/live_practice_screen.dart';

void main() {
  testWidgets('removing live practice does not notify a disposed notifier',
      (tester) async {
    const channel = MethodChannel('com.learnsignph/hand_landmarker');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      return call.method == 'loadEvaluationResults' ? '[]' : null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(
      home: LivePracticeScreen(isActive: false),
    ));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls, contains('stopTracking'));
  });
}
