import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/screens/pin_screen.dart';

Widget _wrap() => const MaterialApp(
    home: PinScreen(storedHash: 'abc', biometricEnabled: false));

Widget _withHome(PinScreen screen) => MaterialApp(
      home: screen,
      routes: {'/home': (_) => const Scaffold(body: Text('Home screen'))},
    );

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

  testWidgets('Face ID unlocks straight away when it is on', (tester) async {
    await tester.pumpWidget(_withHome(PinScreen(
      storedHash: 'abc',
      biometricEnabled: true,
      authenticate: () async => true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('a failed Face ID leaves the PIN pad and a retry button',
      (tester) async {
    var tries = 0;
    await tester.pumpWidget(_withHome(PinScreen(
      storedHash: 'abc',
      biometricEnabled: true,
      authenticate: () async {
        tries++;
        return false;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);

    await tester.tap(find.byTooltip('Use Face ID or fingerprint'));
    await tester.pumpAndSettle();
    expect(tries, 2);
    expect(find.text('Home screen'), findsNothing);
  });

  testWidgets('no Face ID button when it is off', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byTooltip('Use Face ID or fingerprint'), findsNothing);
  });
}
