import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/expense_filter.dart';
import 'package:budgie/models/recurring_expense.dart';

void main() {
  final db = DatabaseHelper.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('budgie_db_').path);
  });

  setUp(() async {
    await db.wipeAll();
  });

  tearDownAll(() async {
    await db.wipeAll();
  });

  Future<void> addExpense(
    double amount,
    String category,
    DateTime date, [
    String note = '',
  ]) =>
      db.insertExpense(Expense(
          amount: amount, category: category, date: date, note: note));

  RecurringExpense rent(DateTime start, {bool active = true}) =>
      RecurringExpense(
        amount: 50000,
        category: 'Bills',
        note: 'Rent',
        frequency: RecurringFrequency.monthly,
        startDate: start,
        nextDue: start,
        active: active,
      );

  group('postDueRecurringExpenses', () {
    test('adds each missed payment and moves next due forward', () async {
      await db.insertRecurringExpense(rent(DateTime(2026, 1, 31)));

      final posted = await db.postDueRecurringExpenses(DateTime(2026, 3, 31));

      expect(posted, 3);
      final feb = await db.expensesForMonth(DateTime(2026, 2));
      expect(feb.single.date, DateTime(2026, 2, 28));
      expect(feb.single.note, 'Rent');
      expect(feb.single.amount, 50000);
      final saved = (await db.getRecurringExpenses()).single;
      expect(saved.nextDue, DateTime(2026, 4, 30));
    });

    test('never adds the same payment twice', () async {
      await db.insertRecurringExpense(rent(DateTime(2026, 5, 1)));
      final now = DateTime(2026, 5, 1, 9);

      final results = await Future.wait([
        db.postDueRecurringExpenses(now),
        db.postDueRecurringExpenses(now),
      ]);

      expect(results.reduce((a, b) => a + b), 1);
      expect(await db.postDueRecurringExpenses(now), 0);
      expect(await db.expensesForMonth(DateTime(2026, 5)), hasLength(1));
    });

    test('skips paused and future items', () async {
      await db.insertRecurringExpense(
          rent(DateTime(2026, 1, 1), active: false));
      await db.insertRecurringExpense(rent(DateTime(2026, 7, 1)));

      expect(await db.postDueRecurringExpenses(DateTime(2026, 6, 1)), 0);
    });

    test('deleting a posted expense does not bring it back', () async {
      await db.insertRecurringExpense(rent(DateTime(2026, 5, 1)));
      await db.postDueRecurringExpenses(DateTime(2026, 5, 2));
      final posted = (await db.expensesForMonth(DateTime(2026, 5))).single;

      await db.deleteExpense(posted.id!);

      expect(await db.postDueRecurringExpenses(DateTime(2026, 5, 3)), 0);
    });
  });

  group('category budgets', () {
    test('saves, replaces and removes a limit', () async {
      await db.setCategoryBudget('Food', 1000);
      await db.setCategoryBudget('Food', 1500);
      await db.setCategoryBudget('Transport', 300);
      expect(await db.getCategoryBudgets(),
          {'Food': 1500.0, 'Transport': 300.0});

      await db.deleteCategoryBudget('Food');
      expect(await db.getCategoryBudgets(), {'Transport': 300.0});
    });
  });

  group('searchExpenses', () {
    setUp(() async {
      await addExpense(100, 'Food', DateTime(2026, 1, 10, 8), 'Cargills rice');
      await addExpense(250, 'Transport', DateTime(2026, 2, 15, 23, 30), 'Taxi');
      await addExpense(900, 'Food', DateTime(2026, 3, 20), 'Birthday 50% off');
      await addExpense(40, 'Other', DateTime(2026, 3, 21), 'snake_case');
    });

    Future<List<String>> search(ExpenseFilter filter) async =>
        (await db.searchExpenses(filter)).map((e) => e.note).toList();

    test('no filter returns everything, newest first', () async {
      expect(await search(const ExpenseFilter()), [
        'snake_case',
        'Birthday 50% off',
        'Taxi',
        'Cargills rice',
      ]);
    });

    test('text matches notes and categories, ignoring case', () async {
      expect(await search(const ExpenseFilter(text: 'CARGILLS')),
          ['Cargills rice']);
      expect(await search(const ExpenseFilter(text: 'transport')), ['Taxi']);
    });

    test('wildcard characters are searched literally', () async {
      expect(await search(const ExpenseFilter(text: '%')),
          ['Birthday 50% off']);
      expect(await search(const ExpenseFilter(text: '_')), ['snake_case']);
    });

    test('quotes in the search text are safe', () async {
      expect(await search(const ExpenseFilter(text: "x' OR '1'='1")), isEmpty);
    });

    test('date range includes the whole last day', () async {
      final result = await search(ExpenseFilter(
        from: DateTime(2026, 2, 15),
        to: DateTime(2026, 2, 15),
      ));
      expect(result, ['Taxi']);
    });

    test('filters combine', () async {
      expect(
        await search(const ExpenseFilter(
            category: 'Food', minAmount: 100, maxAmount: 500)),
        ['Cargills rice'],
      );
    });
  });

  test('upgrading a version 3 database keeps data and adds tables', () async {
    await db.wipeAll();
    final path = join(await getDatabasesPath(), 'expenses.db');
    final old = await openDatabase(path, version: 3, onCreate: (d, _) async {
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, amount REAL NOT NULL, category TEXT NOT NULL, '
          'date TEXT NOT NULL, note TEXT)');
      await d.insert('expenses', {
        'amount': 75.0,
        'category': 'Food',
        'date': DateTime(2026, 4, 2).toIso8601String(),
        'note': 'Old expense',
      });
    });
    await old.close();

    expect((await db.expensesForMonth(DateTime(2026, 4))).single.note,
        'Old expense');
    expect(await db.getRecurringExpenses(), isEmpty);
    expect(await db.getCategoryBudgets(), isEmpty);
  });
}
