import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/debt.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/services/backup_service.dart';
import 'package:budgie/services/receipt_photos.dart';

void main() {
  final db = DatabaseHelper.instance;
  final photos = ReceiptPhotos.instance;
  final may = DateTime(2026, 5, 10);
  late Directory temp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    temp = Directory.systemTemp.createTempSync('budgie_lending_');
    await databaseFactory.setDatabasesPath(temp.path);
    photos.directoryOverride = Directory(join(temp.path, 'receipts'));
  });

  setUp(() async {
    await db.wipeAll();
  });

  tearDownAll(() async {
    await db.wipeAll();
    photos.directoryOverride = null;
  });

  Future<int> lend(double amount, [String person = 'Nimal']) =>
      db.insertDebt(Debt(
          person: person,
          direction: DebtDirection.lent,
          amount: amount,
          date: may));

  Future<bool> repay(int debtId, double amount) => db.addDebtPayment(
      DebtPayment(debtId: debtId, amount: amount, date: may));

  group('lent and borrowed', () {
    test('payments reduce what is owed until settled', () async {
      final id = await lend(1000);
      expect(await repay(id, 400), isTrue);
      expect((await db.getDebts()).single.remaining, 600);

      expect(await repay(id, 600), isTrue);
      expect((await db.getDebts()).single.isSettled, isTrue);
    });

    test('cannot pay back more than is owed', () async {
      final id = await lend(1000);
      await repay(id, 900);

      expect(await repay(id, 200), isFalse);
      expect(await db.paymentsForDebt(id), hasLength(1));
    });

    test('removing a payment reopens the debt', () async {
      final id = await lend(1000);
      await repay(id, 1000);
      final payment = (await db.paymentsForDebt(id)).single;

      await db.deleteDebtPayment(payment.id!);

      expect((await db.getDebts()).single.remaining, 1000);
    });

    test('deleting a debt removes its payments', () async {
      final id = await lend(1000);
      await repay(id, 100);

      await db.deleteDebt(id);

      expect(await db.getDebts(), isEmpty);
      expect(await db.paymentsForDebt(id), isEmpty);
    });

    test('suggests each person once', () async {
      await lend(10, 'Nimal');
      await lend(20, 'Nimal');
      await lend(30, 'amara');
      expect(await db.debtPeople(), ['amara', 'Nimal']);
    });

    test('backup restores debts and payments', () async {
      final id = await lend(1000);
      await repay(id, 250);
      final backup = BackupService.instance;
      final json = await backup.serializeForTest();

      await db.wipeAll();
      backup.setPendingRestoreForTest(json);
      await backup.restoreData();

      expect((await db.getDebts()).single.remaining, 750);
    });
  });

  group('trends', () {
    test('monthly totals cover the window and skip other months', () async {
      for (final (amount, date) in [
        (100.0, DateTime(2026, 3, 31, 23)),
        (50.0, DateTime(2026, 5, 1)),
        (25.0, DateTime(2026, 5, 31, 23, 59)),
        (999.0, DateTime(2026, 6, 1)),
        (999.0, DateTime(2026, 2, 28)),
      ]) {
        await db.insertExpense(
            Expense(amount: amount, category: 'Food', date: date));
      }

      final totals = await db.monthlyTotals(DateTime(2026, 5), 3);

      expect(totals.map((t) => t.total), [100, 0, 75]);
    });

    test('category totals group one month', () async {
      await db.insertExpense(Expense(amount: 10, category: 'Food', date: may));
      await db.insertExpense(Expense(amount: 5, category: 'Food', date: may));
      await db.insertExpense(
          Expense(amount: 7, category: 'Bills', date: DateTime(2026, 4, 2)));

      expect(await db.categoryTotals(may), {'Food': 15.0});
    });
  });

  group('receipt photos', () {
    Future<File> picture() async {
      final f = File(join(temp.path, 'picked.jpg'));
      await f.writeAsBytes([1, 2, 3]);
      return f;
    }

    test('saved photos can be found again', () async {
      final name = await photos.save(await picture());
      final found = await photos.find(name);
      expect(await found!.readAsBytes(), [1, 2, 3]);
      expect(await photos.find('missing.jpg'), isNull);
      expect(await photos.find(null), isNull);
    });

    test('a stored name cannot reach outside the receipts folder', () async {
      final outside = File(join(temp.path, 'secret.jpg'));
      await outside.writeAsBytes([9]);

      expect(await photos.find('../secret.jpg'), isNull);
      await photos.delete('../secret.jpg');
      expect(await outside.exists(), isTrue);
    });

    test('deleting an expense deletes its photo', () async {
      final name = await photos.save(await picture());
      final id = await db.insertExpense(
          Expense(amount: 10, category: 'Food', date: may, photo: name));

      await db.deleteExpense(id);

      expect(await photos.find(name), isNull);
    });
  });

  test('upgrading a version 5 database adds the photo column', () async {
    await db.wipeAll();
    final path = join(await getDatabasesPath(), 'expenses.db');
    final old = await openDatabase(path, version: 5, onCreate: (d, _) async {
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

    final kept = (await db.expensesForMonth(may)).single;
    expect(kept.note, 'Old expense');
    expect(kept.photo, isNull);
    expect(await db.getDebts(), isEmpty);
  });
}
