import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/account.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/household_item.dart';
import 'package:budgie/models/income.dart';
import 'package:budgie/services/backup_service.dart';
import 'package:budgie/services/pdf_report.dart';

void main() {
  final db = DatabaseHelper.instance;
  final may = DateTime(2026, 5, 10);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('budgie_accounts_').path);
  });

  setUp(() async {
    await db.wipeAll();
  });

  tearDownAll(() async {
    await db.wipeAll();
  });

  Future<int> account(String name, [double opening = 0]) => db.insertAccount(
      Account(name: name, type: AccountType.bank, openingBalance: opening));

  Future<double> balanceOf(int id) async =>
      (await db.getAccounts()).firstWhere((a) => a.id == id).balance;

  group('accounts', () {
    test('balance adds income and transfers in, takes off spending',
        () async {
      final bank = await account('Bank', 1000);
      final cash = await account('Cash', 50);
      await db.insertIncome(
          Income(amount: 500, source: 'Salary', date: may, accountId: bank));
      await db.insertExpense(Expense(
          amount: 120, category: 'Food', date: may, accountId: bank));
      await db.insertExpense(
          Expense(amount: 999, category: 'Food', date: may));
      await db.insertTransfer(AccountTransfer(
          fromAccount: bank, toAccount: cash, amount: 200, date: may));

      expect(await balanceOf(bank), 1180);
      expect(await balanceOf(cash), 250);
    });

    test('a transfer to the same account is refused', () async {
      final bank = await account('Bank');
      expect(
        () => db.insertTransfer(AccountTransfer(
            fromAccount: bank, toAccount: bank, amount: 5, date: may)),
        throwsArgumentError,
      );
    });

    test('deleting an account keeps its expenses without an account',
        () async {
      final bank = await account('Bank');
      final cash = await account('Cash');
      await db.insertExpense(Expense(
          amount: 10, category: 'Food', date: may, accountId: bank));
      await db.insertTransfer(AccountTransfer(
          fromAccount: bank, toAccount: cash, amount: 40, date: may));

      await db.deleteAccount(bank);

      final expense = (await db.expensesForMonth(may)).single;
      expect(expense.amount, 10);
      expect(expense.accountId, isNull);
      expect(await balanceOf(cash), 0);
    });

    test('new entries default to the account used last', () async {
      final bank = await account('Bank');
      final cash = await account('Cash');
      var accounts = await db.getAccounts();
      expect(await db.defaultAccountId(accounts), bank);

      await db.rememberAccount(cash);
      expect(await db.defaultAccountId(accounts), cash);

      await db.deleteAccount(cash);
      accounts = await db.getAccounts();
      expect(await db.defaultAccountId(accounts), bank);
      expect(await db.defaultAccountId([]), isNull);
    });

    test('activity lists every movement, newest first', () async {
      final bank = await account('Bank');
      final cash = await account('Cash');
      await db.insertIncome(Income(
          amount: 500,
          source: 'Salary',
          date: DateTime(2026, 5, 1),
          accountId: bank));
      await db.insertExpense(Expense(
          amount: 20,
          category: 'Food',
          date: DateTime(2026, 5, 3),
          accountId: bank));
      await db.insertTransfer(AccountTransfer(
          fromAccount: bank,
          toAccount: cash,
          amount: 100,
          date: DateTime(2026, 5, 2)));

      final activity = await db.accountActivity(bank);

      expect(activity.map((a) => a.title), ['Food', 'To Cash', 'Salary']);
      expect(activity.map((a) => a.amount), [-20, -100, 500]);
      expect((await db.accountActivity(cash)).single.title, 'From Bank');
    });

    test('backup restores accounts and transfers', () async {
      final bank = await account('Bank', 1000);
      final cash = await account('Cash');
      await db.insertTransfer(AccountTransfer(
          fromAccount: bank, toAccount: cash, amount: 300, date: may));
      final backup = BackupService.instance;
      final json = await backup.serializeForTest();

      await db.wipeAll();
      backup.setPendingRestoreForTest(json);
      await backup.restoreData();

      expect(await balanceOf(bank), 700);
      expect(await balanceOf(cash), 300);
    });
  });

  group('recordPurchase', () {
    Future<HouseholdItem> rice() async {
      final id = await db.insertItem(HouseholdItem(
          name: 'Rice', quantity: 0.5, minQuantity: 2, unit: 'kg'));
      return (await db.getAllItems()).firstWhere((i) => i.id == id);
    }

    test('adds stock and records the cost as an expense', () async {
      final bank = await account('Bank', 100);
      final item = await rice();

      await db.recordPurchase(item, 3,
          cost: 40, accountId: bank, date: may);

      expect((await db.getAllItems()).single.quantity, 3.5);
      final expense = (await db.expensesForMonth(may)).single;
      expect(expense.note, 'Bought Rice');
      expect(expense.category, 'Groceries');
      expect(await balanceOf(bank), 60);
    });

    test('without a cost only the stock changes', () async {
      final item = await rice();
      await db.recordPurchase(item, 1, date: may);
      expect((await db.getAllItems()).single.quantity, 1.5);
      expect(await db.expensesForMonth(may), isEmpty);
    });
  });

  test('PDF report builds, including text the font lacks', () async {
    final bytes = await buildMonthlyReport(MonthlyReportData(
      month: DateTime(2026, 5),
      currency: 'Rs.',
      expenses: [
        Expense(amount: 1200, category: 'Food', date: may, note: 'කෑම'),
        Expense(amount: 300, category: 'Bills', date: may, note: 'Water'),
      ],
      balance: const MonthlyBalance(income: 5000, spent: 1500, saved: 500),
      budget: 1000,
      categoryLimits: const {'Food': 1000},
    ));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('a PDF report with no expenses still builds', () async {
    final bytes = await buildMonthlyReport(MonthlyReportData(
      month: DateTime(2026, 5),
      currency: 'Rs.',
      expenses: const [],
      balance: const MonthlyBalance(income: 0, spent: 0, saved: 0),
    ));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('upgrading a version 6 database adds account columns', () async {
    await db.wipeAll();
    final path = join(await getDatabasesPath(), 'expenses.db');
    final old = await openDatabase(path, version: 6, onCreate: (d, _) async {
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, amount REAL NOT NULL, category TEXT NOT NULL, '
          'date TEXT NOT NULL, note TEXT, photo TEXT)');
      await d.execute('CREATE TABLE income(id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, amount REAL NOT NULL, source TEXT NOT NULL, '
          "date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '')");
      await d.insert('expenses', {
        'amount': 75.0,
        'category': 'Food',
        'date': may.toIso8601String(),
        'note': 'Old expense',
      });
    });
    await old.close();

    final kept = (await db.expensesForMonth(may)).single;
    expect(kept.note, 'Old expense');
    expect(kept.accountId, isNull);
    expect(await db.incomeForMonth(may), isEmpty);
    expect(await db.getAccounts(), isEmpty);
  });
}
