import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/screens/pin_screen.dart';

Widget _wrap() => const MaterialApp(home: PinScreen(storedHash: 'abc'));

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  testWidgets('Forgot PIN button hidden until 5 failures', (tester) async {
    await tester.pumpWidget(_wrap());

    // 4 wrong attempts — button must NOT appear
    for (int i = 0; i < 4; i++) {
      await _tapDigits(tester, '9999');
      await tester.pump();
    }
    expect(find.text('Forgot PIN?'), findsNothing);

    // 5th wrong attempt — button MUST appear
    await _tapDigits(tester, '9999');
    await tester.pump();
    expect(find.text('Forgot PIN?'), findsOneWidget);
  });
}
