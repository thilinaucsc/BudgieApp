import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/screens/settings_screen.dart';

Widget _wrap({bool pinSet = false, String? googleEmail}) => MaterialApp(
      home: SettingsScreen(
        month: DateTime(2026, 10),
        initialPinSet: pinSet,
        initialGoogleEmail: googleEmail,
      ),
    );

void main() {
  testWidgets('shows Set PIN when no PIN is configured', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Set PIN'), findsOneWidget);
  });

  testWidgets('shows Change PIN when PIN is already set', (tester) async {
    await tester.pumpWidget(_wrap(pinSet: true));
    expect(find.text('Change PIN'), findsOneWidget);
  });
}
