import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/screens/set_pin_screen.dart';

Widget _wrap() => const MaterialApp(home: SetPinScreen());

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  testWidgets('shows mismatch snackbar when PINs differ', (tester) async {
    await tester.pumpWidget(_wrap());
    await _tapDigits(tester, '1234');      // first entry
    await _tapDigits(tester, '5678');      // mismatched confirm
    await tester.pump();
    expect(find.text('PINs do not match'), findsOneWidget);
  });

  testWidgets('resets to step 0 after mismatch', (tester) async {
    await tester.pumpWidget(_wrap());
    await _tapDigits(tester, '1234');
    await _tapDigits(tester, '5678');
    await tester.pump();
    // Should show "Enter new PIN" label again
    expect(find.text('Enter new PIN'), findsOneWidget);
  });
}
