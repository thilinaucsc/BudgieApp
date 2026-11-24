import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/favourite.dart';
import 'package:budgie/models/recurring_expense.dart';
import 'package:budgie/screens/add_recurring_screen.dart';
import 'package:budgie/screens/calendar_screen.dart';
import 'package:budgie/screens/favourites_screen.dart';
import 'package:budgie/screens/home_screen.dart';
import 'package:budgie/screens/recurring_screen.dart';

final _db = DatabaseHelper.instance;

// The no-isolate factory answers on microtasks, so pumping lets queries finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('budgie_quick_screens_').path,
    );
  });

  setUp(() async {
    await _db.wipeAll();
    await _db.database;
  });

  tearDownAll(() async {
    await _db.wipeAll();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
    await _settle(tester);
  }

  testWidgets('tapping a favourite on home adds it, and undo removes it', (
    tester,
  ) async {
    await tester.runAsync(
      () => _db.insertFavourite(
        const Favourite(amount: 120, category: 'Transport', note: 'Bus fare'),
      ),
    );

    await pumpScreen(tester, const HomeScreen());
    await tester.tap(find.text('Bus fare · 120.00'));
    await _settle(tester);

    expect(find.text('Added Bus fare, Rs. 120.00'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.text('No expenses this month'), findsOneWidget);
  });

  testWidgets('a favourite is created from the quick add screen', (
    tester,
  ) async {
    await pumpScreen(tester, const FavouritesScreen());
    expect(find.text('No favourites yet'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Tea');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text('Tea'), findsOneWidget);
  });

  testWidgets('recurring form switches to income sources', (tester) async {
    await pumpScreen(tester, const AddRecurringScreen(currency: 'Rs.'));
    expect(find.text('Category'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Save recurring income'), findsOneWidget);
  });

  testWidgets('recurring list marks income with a plus', (tester) async {
    final next = DateTime.now().add(const Duration(days: 5));
    final due = DateTime(next.year, next.month, next.day);
    await tester.runAsync(
      () => _db.insertRecurringExpense(
        RecurringExpense(
          amount: 150000,
          category: 'Salary',
          frequency: RecurringFrequency.monthly,
          startDate: due,
          nextDue: due,
          isIncome: true,
        ),
      ),
    );

    await pumpScreen(tester, const RecurringScreen());

    expect(find.text('+Rs. 150,000.00'), findsOneWidget);
  });

  testWidgets('calendar shows daily totals and the chosen day', (tester) async {
    await tester.runAsync(() async {
      await _db.insertExpense(
        Expense(
          amount: 1250,
          category: 'Food',
          date: DateTime(2026, 5, 6),
          note: 'Lunch',
        ),
      );
      await _db.insertExpense(
        Expense(amount: 300, category: 'Bills', date: DateTime(2026, 5, 20)),
      );
    });

    await pumpScreen(
      tester,
      CalendarScreen(month: DateTime(2026, 5), currency: 'Rs.'),
    );

    expect(find.text('1.3k'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('Spent Rs. 1,550.00'), findsOneWidget);

    await tester.tap(find.text('1.3k'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lunch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Wednesday, 6 May'), findsOneWidget);
  });

  testWidgets('new screens render in dark mode', (tester) async {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.dark,
      ),
    );
    await tester.runAsync(
      () => _db.insertExpense(
        Expense(amount: 50, category: 'Food', date: DateTime(2026, 5, 6)),
      ),
    );
    for (final screen in <Widget>[
      CalendarScreen(month: DateTime(2026, 5), currency: 'Rs.'),
      const FavouritesScreen(),
    ]) {
      await pumpScreen(tester, screen, theme: dark);
      expect(tester.takeException(), isNull);
    }
  });
}
