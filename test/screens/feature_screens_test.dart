import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/recurring_expense.dart';
import 'package:budgie/screens/add_recurring_screen.dart';
import 'package:budgie/screens/category_budgets_screen.dart';
import 'package:budgie/screens/home_screen.dart';
import 'package:budgie/screens/recurring_screen.dart';
import 'package:budgie/screens/search_screen.dart';

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
      Directory.systemTemp.createTempSync('budgie_screens_').path,
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

  testWidgets('recurring screen shows the empty state', (tester) async {
    await pumpScreen(tester, const RecurringScreen());
    expect(find.text('Nothing recurring yet'), findsOneWidget);
  });

  testWidgets('recurring screen lists an item and pauses it', (tester) async {
    final next = DateTime.now().add(const Duration(days: 5));
    final due = DateTime(next.year, next.month, next.day);
    await tester.runAsync(
      () => _db.insertRecurringExpense(
        RecurringExpense(
          amount: 1500,
          category: 'Bills',
          note: 'Internet',
          frequency: RecurringFrequency.monthly,
          startDate: due,
          nextDue: due,
        ),
      ),
    );

    await pumpScreen(tester, const RecurringScreen());
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Rs. 1,500.00'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(find.text('Monthly · Paused'), findsOneWidget);
  });

  testWidgets('recurring form rejects an empty amount', (tester) async {
    await pumpScreen(tester, const AddRecurringScreen(currency: 'Rs.'));
    await tester.tap(find.text('Save recurring expense'));
    await tester.pump();
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
  });

  testWidgets('category budgets shows over-limit spending', (tester) async {
    final month = DateTime(2026, 5);
    await tester.runAsync(() async {
      await _db.setCategoryBudget('Food', 100);
      await _db.insertExpense(
        Expense(amount: 130, category: 'Food', date: DateTime(2026, 5, 3)),
      );
    });

    await pumpScreen(tester, CategoryBudgetsScreen(month: month));

    expect(find.text('Over by Rs. 30.00'), findsOneWidget);
    expect(find.text('Set limit'), findsWidgets);
  });

  testWidgets('category budgets saves a new limit', (tester) async {
    await pumpScreen(tester, CategoryBudgetsScreen(month: DateTime(2026, 5)));

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text('Rs. 500.00 left'), findsOneWidget);
  });

  testWidgets('search narrows results as you type', (tester) async {
    await tester.runAsync(() async {
      await _db.insertExpense(
        Expense(
          amount: 10,
          category: 'Food',
          date: DateTime(2026, 5, 3),
          note: 'Tea',
        ),
      );
      await _db.insertExpense(
        Expense(
          amount: 20,
          category: 'Bills',
          date: DateTime(2026, 5, 4),
          note: 'Water',
        ),
      );
    });

    await pumpScreen(tester, const SearchScreen(currency: 'Rs.'));
    expect(find.text('2 expenses'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'water');
    await _settle(tester);

    expect(find.text('1 expense'), findsOneWidget);
    expect(find.text('Rs. 20.00'), findsNWidgets(2));
  });

  testWidgets('home posts due recurring expenses and warns on budget', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _db.setCategoryBudget('Bills', 1000);
      await _db.insertRecurringExpense(
        RecurringExpense(
          amount: 1200,
          category: 'Bills',
          note: 'Electricity',
          frequency: RecurringFrequency.monthly,
          startDate: today,
          nextDue: today,
        ),
      );
    });

    await pumpScreen(tester, const HomeScreen());

    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Added 1 recurring entry'), findsOneWidget);
    expect(find.text('Bills is over budget'), findsOneWidget);
  });

  testWidgets('new screens render in dark mode', (tester) async {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.dark,
      ),
    );
    await pumpScreen(
      tester,
      CategoryBudgetsScreen(month: DateTime(2026, 5)),
      theme: dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Category budgets'), findsOneWidget);
  });
}
