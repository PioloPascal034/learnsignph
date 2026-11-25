import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/widgets/sign_gif_tile.dart';

void main() {
  testWidgets('large sign tile fits the lesson quiz media area',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 206,
              child: SignGifTile(
                gifUrl: '',
                word: 'Book',
                isLarge: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Book'), findsOneWidget);
  });
}
