import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/custom_category.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/expense_category.dart';
import 'package:budgie/models/income.dart';
import 'package:budgie/models/recurring_expense.dart';
import 'package:budgie/models/savings_goal.dart';
import 'package:budgie/services/backup_service.dart';

void main() {
  final db = DatabaseHelper.instance;
  final may = DateTime(2026, 5, 10);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('budgie_money_').path);
  });

  setUp(() async {
    await db.wipeAll();
  });

  tearDownAll(() async {
    await db.wipeAll();
  });

  Future<int> addGoal([String name = 'Phone']) => db.insertSavingsGoal(
      SavingsGoal(name: name, targetAmount: 1000, createdAt: may));

  Future<bool> move(int goalId, double amount, [DateTime? date]) =>
      db.addSavingsContribution(SavingsContribution(
          goalId: goalId, amount: amount, date: date ?? may));

  const pets = CustomCategory(
      name: 'Pets', iconKey: 'pets', colorValue: 0xFF00897B);

  group('custom categories', () {
    test('saved categories become available straight away', () async {
      await db.insertCustomCategory(pets);
      expect(categories.map((c) => c.name), contains('Pets'));
    });

    test('renaming moves expenses, bills and budgets', () async {
      final id = await db.insertCustomCategory(pets);
      await db.insertExpense(
          Expense(amount: 10, category: 'Pets', date: may, note: 'Vet'));
      await db.insertRecurringExpense(RecurringExpense(
        amount: 20,
        category: 'Pets',
        frequency: RecurringFrequency.monthly,
        startDate: may,
        nextDue: may,
      ));
      await db.setCategoryBudget('Pets', 500);

      await db.updateCustomCategory(
        CustomCategory(
            id: id, name: 'Animals', iconKey: 'pets', colorValue: 0xFF00897B),
        'Pets',
      );

      expect((await db.expensesForMonth(may)).single.category, 'Animals');
      expect((await db.getRecurringExpenses()).single.category, 'Animals');
      expect(await db.getCategoryBudgets(), {'Animals': 500.0});
      expect(categories.map((c) => c.name), isNot(contains('Pets')));
    });

    test('deleting moves spending to Other and removes the budget', () async {
      final id = await db.insertCustomCategory(pets);
      await db.insertExpense(Expense(amount: 10, category: 'Pets', date: may));
      await db.setCategoryBudget('Pets', 500);

      await db.deleteCustomCategory(CustomCategory(
          id: id, name: 'Pets', iconKey: 'pets', colorValue: 0xFF00897B));

      final expense = (await db.expensesForMonth(may)).single;
      expect(expense.category, 'Other');
      expect(expense.amount, 10);
      expect(await db.getCategoryBudgets(), isEmpty);
      expect(categories.map((c) => c.name), isNot(contains('Pets')));
    });
  });

  group('monthly balance', () {
    test('counts only the chosen month', () async {
      await db.insertIncome(
          Income(amount: 1000, source: 'Salary', date: may));
      await db.insertIncome(Income(
          amount: 999, source: 'Salary', date: DateTime(2026, 6, 1)));
      await db.insertExpense(Expense(amount: 300, category: 'Food', date: may));
      final goal = await addGoal();
      await move(goal, 200);

      final balance = await db.monthlyBalance(DateTime(2026, 5));

      expect(balance.income, 1000);
      expect(balance.spent, 300);
      expect(balance.saved, 200);
      expect(balance.left, 500);
    });

    test('income on the last moment of a month stays in that month', () async {
      await db.insertIncome(Income(
          amount: 50,
          source: 'Gift',
          date: DateTime(2026, 5, 31, 23, 59)));
      expect(await db.incomeForMonth(DateTime(2026, 5)), hasLength(1));
      expect(await db.incomeForMonth(DateTime(2026, 6)), isEmpty);
    });

    test('income can be edited and deleted', () async {
      final id = await db
          .insertIncome(Income(amount: 100, source: 'Salary', date: may));
      await db.updateIncome(
          Income(id: id, amount: 150, source: 'Business', date: may));
      final saved = (await db.incomeForMonth(may)).single;
      expect(saved.amount, 150);
      expect(saved.source, 'Business');

      await db.deleteIncome(id);
      expect(await db.incomeForMonth(may), isEmpty);
    });
  });

  group('savings goals', () {
    test('totals each goal separately', () async {
      final phone = await addGoal('Phone');
      final trip = await addGoal('Trip');
      await move(phone, 100, DateTime(2026, 5, 2));
      await move(phone, 50, DateTime(2026, 5, 1));
      await move(trip, 25);

      final goals = await db.getSavingsGoals();
      final saved = goals.firstWhere((g) => g.id == phone);
      expect(saved.saved, 150);
      expect(saved.firstContribution, DateTime(2026, 5, 1));
      expect(goals.firstWhere((g) => g.id == trip).saved, 25);
    });

    test('a goal with no money reports zero', () async {
      await addGoal();
      final goal = (await db.getSavingsGoals()).single;
      expect(goal.saved, 0);
      expect(goal.firstContribution, isNull);
    });

    test('cannot withdraw more than the goal holds', () async {
      final goal = await addGoal();
      await move(goal, 100);

      expect(await move(goal, -150), isFalse);
      expect((await db.getSavingsGoals()).single.saved, 100);
      expect(await move(goal, -100), isTrue);
      expect((await db.getSavingsGoals()).single.saved, 0);
    });

    test('cannot remove a deposit that was already withdrawn', () async {
      final goal = await addGoal();
      await move(goal, 100);
      await move(goal, -80);
      final history = await db.contributionsForGoal(goal);
      final deposit = history.firstWhere((c) => !c.isWithdrawal);
      final withdrawal = history.firstWhere((c) => c.isWithdrawal);

      expect(await db.deleteSavingsContribution(deposit), isFalse);
      expect(await db.contributionsForGoal(goal), hasLength(2));
      expect(await db.deleteSavingsContribution(withdrawal), isTrue);
      expect(await db.deleteSavingsContribution(deposit), isTrue);
    });

    test('deleting a goal removes its history and frees the money', () async {
      final goal = await addGoal();
      await move(goal, 100);

      await db.deleteSavingsGoal(goal);

      expect(await db.getSavingsGoals(), isEmpty);
      expect(await db.contributionsForGoal(goal), isEmpty);
      expect((await db.monthlyBalance(may)).saved, 0);
    });
  });

  test('backup restores income, goals and custom categories', () async {
    final backup = BackupService.instance;
    await db.insertCustomCategory(pets);
    await db.insertIncome(Income(amount: 1000, source: 'Salary', date: may));
    await move(await addGoal(), 100);
    final json = await backup.serializeForTest();

    await db.wipeAll();
    backup.setPendingRestoreForTest(json);
    await backup.restoreData();

    expect(categories.map((c) => c.name), contains('Pets'));
    expect((await db.incomeForMonth(may)).single.amount, 1000);
    expect((await db.getSavingsGoals()).single.saved, 100);
  });

  test('a backup from before these tables keeps local data', () async {
    final backup = BackupService.instance;
    final old = jsonDecode(await backup.serializeForTest())
        as Map<String, dynamic>
      ..remove('income')
      ..remove('savings_goals')
      ..remove('savings_contributions')
      ..remove('custom_categories');
    await db.insertIncome(Income(amount: 1000, source: 'Salary', date: may));

    backup.setPendingRestoreForTest(jsonEncode(old));
    await backup.restoreData();

    expect(await db.incomeForMonth(may), hasLength(1));
  });

  test('upgrading a version 4 database keeps data and adds tables', () async {
    await db.wipeAll();
    final path = join(await getDatabasesPath(), 'expenses.db');
    final old = await openDatabase(path, version: 4, onCreate: (d, _) async {
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, amount REAL NOT NULL, category TEXT NOT NULL, '
          'date TEXT NOT NULL, note TEXT)');
      await d.insert('expenses', {
        'amount': 75.0,
        'category': 'Food',
        'date': may.toIso8601String(),
        'note': 'Old expense',
      });
    });
    await old.close();

    expect((await db.expensesForMonth(may)).single.note, 'Old expense');
    expect(await db.incomeForMonth(may), isEmpty);
    expect(await db.getSavingsGoals(), isEmpty);
    expect(await db.getCustomCategories(), isEmpty);
  });
}
