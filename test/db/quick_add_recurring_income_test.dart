import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/account.dart';
import 'package:budgie/models/custom_category.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/favourite.dart';
import 'package:budgie/models/recurring_expense.dart';
import 'package:budgie/services/backup_service.dart';

void main() {
  final db = DatabaseHelper.instance;
  final may = DateTime(2026, 5, 10);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('budgie_quick_add_').path,
    );
  });

  setUp(() async {
    await db.wipeAll();
  });

  tearDownAll(() async {
    await db.wipeAll();
  });

  RecurringExpense salary({int? accountId, String source = 'Salary'}) =>
      RecurringExpense(
        amount: 150000,
        category: source,
        note: 'Monthly pay',
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 31),
        nextDue: DateTime(2026, 1, 31),
        isIncome: true,
        accountId: accountId,
      );

  group('recurring income', () {
    test('salary is added as income, not as spending', () async {
      await db.insertRecurringExpense(salary());

      expect(await db.postDueRecurringExpenses(DateTime(2026, 3, 31)), 3);

      final feb = await db.incomeForMonth(DateTime(2026, 2));
      expect(feb.single.amount, 150000);
      expect(feb.single.source, 'Salary');
      expect(feb.single.date, DateTime(2026, 2, 28));
      expect(feb.single.note, 'Monthly pay');
      expect(await db.expensesForMonth(DateTime(2026, 2)), isEmpty);
    });

    test('posts into its account, or none once that is deleted', () async {
      final bank = await db.insertAccount(
        Account(name: 'Bank', type: AccountType.bank),
      );
      final gone = await db.insertAccount(
        Account(name: 'Old', type: AccountType.bank),
      );
      await db.insertRecurringExpense(salary(accountId: bank));
      await db.insertRecurringExpense(
        salary(accountId: gone, source: 'Business'),
      );
      await db.deleteAccount(gone);

      await db.postDueRecurringExpenses(DateTime(2026, 1, 31));

      final paid = await db.incomeForMonth(DateTime(2026, 1));
      expect(paid.firstWhere((i) => i.source == 'Salary').accountId, bank);
      expect(paid.firstWhere((i) => i.source == 'Business').accountId, isNull);
      final accounts = await db.getAccounts();
      expect(accounts.single.balance, 150000);
    });

    test('a custom category named like a source leaves income alone', () async {
      final id = await db.insertCustomCategory(
        const CustomCategory(
          name: 'Salary',
          iconKey: 'work',
          colorValue: 0xFF00897B,
        ),
      );
      await db.insertRecurringExpense(salary());

      await db.deleteCustomCategory(
        const CustomCategory(
          name: 'Salary',
          iconKey: 'work',
          colorValue: 0xFF00897B,
        ).copyForTest(id),
      );

      expect((await db.getRecurringExpenses()).single.category, 'Salary');
    });
  });

  group('quick add', () {
    test('adds the favourite as an expense that can be undone', () async {
      await db.insertFavourite(
        const Favourite(amount: 120, category: 'Transport', note: 'Bus fare'),
      );
      final fav = (await db.getFavourites()).single;

      final id = await db.addFavouriteExpense(fav, may);

      final added = (await db.expensesForMonth(may)).single;
      expect(added.note, 'Bus fare');
      expect(added.amount, 120);
      await db.deleteExpense(id);
      expect(await db.expensesForMonth(may), isEmpty);
    });

    test('a deleted account is dropped instead of reused', () async {
      final cash = await db.insertAccount(
        Account(name: 'Cash', type: AccountType.cash),
      );
      await db.insertFavourite(
        Favourite(amount: 50, category: 'Food', accountId: cash),
      );
      await db.deleteAccount(cash);
      final fav = (await db.getFavourites()).single;
      expect(fav.accountId, isNull);

      await db.addFavouriteExpense(
        Favourite(amount: 50, category: 'Food', accountId: cash),
        may,
      );
      expect((await db.expensesForMonth(may)).single.accountId, isNull);
    });

    test('follows a custom category when it is renamed or deleted', () async {
      final id = await db.insertCustomCategory(
        const CustomCategory(
          name: 'Pets',
          iconKey: 'pets',
          colorValue: 0xFF00897B,
        ),
      );
      await db.insertFavourite(
        const Favourite(amount: 300, category: 'Pets', note: 'Dog food'),
      );

      await db.updateCustomCategory(
        CustomCategory(
          id: id,
          name: 'Animals',
          iconKey: 'pets',
          colorValue: 0xFF00897B,
        ),
        'Pets',
      );
      expect((await db.getFavourites()).single.category, 'Animals');

      await db.deleteCustomCategory(
        CustomCategory(
          id: id,
          name: 'Animals',
          iconKey: 'pets',
          colorValue: 0xFF00897B,
        ),
      );
      expect((await db.getFavourites()).single.category, 'Other');
    });

    test('favourites are kept in backups', () async {
      await db.insertFavourite(
        const Favourite(amount: 120, category: 'Transport', note: 'Bus'),
      );
      final backup = BackupService.instance;
      final json = await backup.serializeForTest();

      await db.wipeAll();
      backup.setPendingRestoreForTest(json);
      await backup.restoreData();

      expect((await db.getFavourites()).single.label, 'Bus');
    });
  });

  test('daily totals group spending by day of the month', () async {
    for (final (amount, date) in [
      (100.0, DateTime(2026, 5, 1, 9)),
      (50.0, DateTime(2026, 5, 1, 21)),
      (25.0, DateTime(2026, 5, 31, 23, 59)),
      (999.0, DateTime(2026, 6, 1)),
    ]) {
      await db.insertExpense(
        Expense(amount: amount, category: 'Food', date: date),
      );
    }

    expect(await db.dailyTotals(DateTime(2026, 5)), {1: 150.0, 31: 25.0});
  });

  test('upgrading a version 7 database keeps recurring items', () async {
    await db.wipeAll();
    final path = join(await getDatabasesPath(), 'expenses.db');
    final old = await openDatabase(
      path,
      version: 7,
      onCreate: (d, _) async {
        await d.execute(
          'CREATE TABLE recurring_expenses(id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, amount REAL NOT NULL, category TEXT NOT NULL, '
          "note TEXT NOT NULL DEFAULT '', frequency TEXT NOT NULL, "
          'start_date TEXT NOT NULL, next_due TEXT NOT NULL, '
          'active INTEGER NOT NULL DEFAULT 1)',
        );
        await d.insert('recurring_expenses', {
          'amount': 5000.0,
          'category': 'Bills',
          'frequency': 'monthly',
          'start_date': may.toIso8601String(),
          'next_due': may.toIso8601String(),
        });
      },
    );
    await old.close();

    final kept = (await db.getRecurringExpenses()).single;
    expect(kept.category, 'Bills');
    expect(kept.isIncome, isFalse);
    expect(kept.accountId, isNull);
    expect(await db.getFavourites(), isEmpty);
  });
}

extension on CustomCategory {
  CustomCategory copyForTest(int id) => CustomCategory(
    id: id,
    name: name,
    iconKey: iconKey,
    colorValue: colorValue,
  );
}
