import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/main.dart';

void main() {
  testWidgets('unauthenticated auth state shows login and not protected shell',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateStream: Stream.value(null),
          authenticatedBuilder: (_) => const Text('protected shell'),
          unauthenticatedBuilder: (_) => const Text('login screen'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('login screen'), findsOneWidget);
    expect(find.text('protected shell'), findsNothing);
  });

  testWidgets('auth gate shows a loading state while auth state is pending',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateStream: const Stream<User?>.empty(),
          authenticatedBuilder: (_) => const Text('protected shell'),
          unauthenticatedBuilder: (_) => const Text('login screen'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
