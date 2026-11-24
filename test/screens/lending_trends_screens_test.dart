import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/debt.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/screens/add_debt_screen.dart';
import 'package:budgie/screens/add_expense_screen.dart';
import 'package:budgie/screens/debt_detail_screen.dart';
import 'package:budgie/screens/debts_screen.dart';
import 'package:budgie/screens/trends_screen.dart';

final _db = DatabaseHelper.instance;

// The no-isolate factory answers on microtasks, so pumping lets queries finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final may = DateTime(2026, 5, 10);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('budgie_lending_screens_').path);
  });

  setUp(() async {
    await _db.wipeAll();
    await _db.database;
  });

  tearDownAll(() async {
    await _db.wipeAll();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen,
      {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
    await _settle(tester);
  }

  Future<int> lend(double amount, String person,
          {DebtDirection direction = DebtDirection.lent}) =>
      _db.insertDebt(Debt(
          person: person, direction: direction, amount: amount, date: may));

  testWidgets('debts list shows totals and each person', (tester) async {
    await tester.runAsync(() async {
      await lend(1000, 'Nimal');
      await lend(400, 'Kamal', direction: DebtDirection.borrowed);
    });

    await pumpScreen(tester, const DebtsScreen());

    expect(find.text('Owed to you'), findsOneWidget);
    expect(find.text('Owes you Rs. 1,000.00'), findsOneWidget);
    expect(find.text('You owe Rs. 400.00'), findsOneWidget);
  });

  testWidgets('paid in full moves a debt to paid back', (tester) async {
    late int id;
    await tester.runAsync(() async => id = await lend(1000, 'Nimal'));

    await pumpScreen(tester, DebtDetailScreen(debtId: id, currency: 'Rs.'));
    expect(find.text('Nimal still owes you'), findsOneWidget);

    await tester.tap(find.text('Paid in full'));
    await _settle(tester);

    expect(find.text('Paid back in full'), findsOneWidget);
    expect(find.text('Paid in full'), findsNothing);
  });

  testWidgets('a part payment larger than the debt is refused',
      (tester) async {
    late int id;
    await tester.runAsync(() async => id = await lend(1000, 'Nimal'));

    await pumpScreen(tester, DebtDetailScreen(debtId: id, currency: 'Rs.'));
    await tester.tap(find.text('Part payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1500');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Only Rs. 1,000.00 is left'), findsOneWidget);
  });

  testWidgets('debt form needs a name and amount', (tester) async {
    await pumpScreen(tester, const AddDebtScreen(currency: 'Rs.'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
  });

  testWidgets('trends compare this month with last month', (tester) async {
    await tester.runAsync(() async {
      await _db.insertExpense(
          Expense(amount: 150, category: 'Food', date: DateTime(2026, 5, 3)));
      await _db.insertExpense(
          Expense(amount: 100, category: 'Food', date: DateTime(2026, 4, 3)));
    });

    await pumpScreen(tester,
        TrendsScreen(month: DateTime(2026, 5), currency: 'Rs.'));

    expect(find.text('50% more than last month'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('+Rs. 50.00'), 200);
    expect(find.text('Spending more on'), findsOneWidget);
    expect(find.text('+Rs. 50.00'), findsOneWidget);

    await tester.tap(find.text('12 months'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense form offers a receipt photo', (tester) async {
    await pumpScreen(tester, const AddExpenseScreen());
    expect(find.text('Attach receipt photo'), findsOneWidget);
  });

  testWidgets('new screens render in dark mode', (tester) async {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.dark,
      ),
    );
    await tester.runAsync(() async => lend(1000, 'Nimal'));
    for (final screen in <Widget>[
      const DebtsScreen(),
      TrendsScreen(month: DateTime(2026, 5), currency: 'Rs.'),
      const AddDebtScreen(currency: 'Rs.'),
    ]) {
      await pumpScreen(tester, screen, theme: dark);
      expect(tester.takeException(), isNull);
    }
  });
}
