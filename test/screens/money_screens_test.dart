import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/custom_category.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/income.dart';
import 'package:budgie/models/savings_goal.dart';
import 'package:budgie/screens/add_expense_screen.dart';
import 'package:budgie/screens/add_goal_screen.dart';
import 'package:budgie/screens/add_income_screen.dart';
import 'package:budgie/screens/categories_screen.dart';
import 'package:budgie/screens/goal_detail_screen.dart';
import 'package:budgie/screens/home_screen.dart';
import 'package:budgie/screens/income_screen.dart';
import 'package:budgie/screens/reminders_screen.dart';
import 'package:budgie/screens/savings_goals_screen.dart';

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
        Directory.systemTemp.createTempSync('budgie_money_screens_').path);
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

  testWidgets('income screen shows what is left this month', (tester) async {
    await tester.runAsync(() async {
      await _db.insertIncome(Income(
          amount: 1000, source: 'Salary', date: may, note: 'May pay'));
      await _db.insertExpense(Expense(amount: 1250, category: 'Food', date: may));
    });

    await pumpScreen(tester, IncomeScreen(month: DateTime(2026, 5)));

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('10 May · May pay'), findsOneWidget);
    expect(find.text('-Rs. 250.00'), findsOneWidget);
  });

  testWidgets('income form rejects an empty amount', (tester) async {
    await pumpScreen(
        tester, AddIncomeScreen(currency: 'Rs.', initialDate: may));
    await tester.tap(find.text('Save income'));
    await tester.pump();
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
  });

  testWidgets('home shows income, savings and balance', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await _db.insertIncome(
          Income(amount: 5000, source: 'Salary', date: now));
      final goal = await _db.insertSavingsGoal(
          SavingsGoal(name: 'Phone', targetAmount: 900, createdAt: now));
      await _db.addSavingsContribution(
          SavingsContribution(goalId: goal, amount: 800, date: now));
    });

    await pumpScreen(tester, const HomeScreen());

    expect(find.text('Rs. 5,000.00'), findsOneWidget);
    expect(find.text('Rs. 800.00'), findsOneWidget);
    expect(find.text('Rs. 4,200.00'), findsOneWidget);
  });

  testWidgets('goals list shows progress', (tester) async {
    await tester.runAsync(() async {
      final goal = await _db.insertSavingsGoal(
          SavingsGoal(name: 'New phone', targetAmount: 1000, createdAt: may));
      await _db.addSavingsContribution(
          SavingsContribution(goalId: goal, amount: 250, date: may));
    });

    await pumpScreen(tester, const SavingsGoalsScreen());

    expect(find.text('New phone'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Rs. 250.00 of Rs. 1,000.00'), findsOneWidget);
  });

  testWidgets('goal form needs a name and target', (tester) async {
    await pumpScreen(tester, const AddGoalScreen(currency: 'Rs.'));
    await tester.tap(find.text('Create goal'));
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
  });

  testWidgets('adding money updates the goal', (tester) async {
    late int goal;
    await tester.runAsync(() async {
      goal = await _db.insertSavingsGoal(
          SavingsGoal(name: 'Phone', targetAmount: 1000, createdAt: may));
    });

    await pumpScreen(tester, GoalDetailScreen(goalId: goal, currency: 'Rs.'));
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '400');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text('Rs. 400.00'), findsOneWidget);
    expect(find.text('Rs. 600.00'), findsOneWidget);
    expect(find.text('+Rs. 400.00'), findsOneWidget);
  });

  testWidgets('withdrawing more than is saved is refused', (tester) async {
    late int goal;
    await tester.runAsync(() async {
      goal = await _db.insertSavingsGoal(
          SavingsGoal(name: 'Phone', targetAmount: 1000, createdAt: may));
      await _db.addSavingsContribution(
          SavingsContribution(goalId: goal, amount: 100, date: may));
    });

    await pumpScreen(tester, GoalDetailScreen(goalId: goal, currency: 'Rs.'));
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('This goal holds Rs. 100.00'), findsOneWidget);
  });

  testWidgets('a new category can be created and used', (tester) async {
    await pumpScreen(tester, const CategoriesScreen());
    expect(find.text('No custom categories'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Pets');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('Pets'), findsOneWidget);

    await pumpScreen(tester, const AddExpenseScreen());
    expect(find.text('Pets'), findsOneWidget);
  });

  testWidgets('a duplicate category name is refused', (tester) async {
    await pumpScreen(tester, const CategoriesScreen());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'food');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('A category with this name already exists'),
        findsOneWidget);
  });

  testWidgets('deleting a category asks first', (tester) async {
    await tester.runAsync(() => _db.insertCustomCategory(const CustomCategory(
        name: 'Pets', iconKey: 'pets', colorValue: 0xFF00897B)));

    await pumpScreen(tester, const CategoriesScreen());
    await tester.tap(find.byTooltip('Delete Pets'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Pets?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('No custom categories'), findsOneWidget);
  });

  testWidgets('reminders stay off when permission is not given',
      (tester) async {
    await pumpScreen(tester, const RemindersScreen());

    await tester.tap(find.text('Bill reminders'));
    // The permission request goes through a real platform channel call.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await _settle(tester);

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isFalse);
    expect(find.text('Allow notifications for Budgie in your phone settings'),
        findsOneWidget);
  });

  testWidgets('saved reminder choices are shown', (tester) async {
    await tester.runAsync(() async {
      await _db.setSetting('bill_reminders', '1');
      await _db.setSetting('bill_reminder_days', '3');
      await _db.setSetting('daily_reminder', '1');
      await _db.setSetting('daily_reminder_time', '7:05');
    });

    await pumpScreen(tester, const RemindersScreen());

    expect(find.text('3 days before'), findsOneWidget);
    expect(find.text('7:05 AM'), findsOneWidget);
  });

  testWidgets('new screens render in dark mode', (tester) async {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.dark,
      ),
    );
    for (final screen in <Widget>[
      IncomeScreen(month: DateTime(2026, 5)),
      const SavingsGoalsScreen(),
      const CategoriesScreen(),
      const RemindersScreen(),
    ]) {
      await pumpScreen(tester, screen, theme: dark);
      expect(tester.takeException(), isNull);
    }
  });
}
