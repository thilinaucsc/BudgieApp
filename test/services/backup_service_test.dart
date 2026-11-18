import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/splitter_expense.dart';
import 'package:budgie/models/splitter_participant.dart';
import 'package:budgie/models/splitter_trip.dart';
import 'package:budgie/services/backup_service.dart';

void main() {
  final db = DatabaseHelper.instance;
  final backup = BackupService.instance;
  final may = DateTime(2026, 5, 3);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('budgie_backup_').path);
  });

  setUp(() async {
    await db.wipeAll();
  });

  tearDownAll(() async {
    await db.wipeAll();
  });

  Future<int> addTrip(String name) async {
    final tripId = await db.insertSplitterTrip(
        SplitterTrip(name: name, createdAt: may));
    final asha = await db.insertSplitterParticipant(
        SplitterParticipant(tripId: tripId, name: 'Asha'));
    final ravi = await db.insertSplitterParticipant(
        SplitterParticipant(tripId: tripId, name: 'Ravi'));
    await db.insertSplitterExpense(SplitterExpense(
      tripId: tripId,
      payerId: asha,
      amount: 4000,
      note: 'Hotel',
      date: may,
      shareParticipantIds: [asha, ravi],
    ));
    return tripId;
  }

  Future<void> addExpense(String note) => db.insertExpense(
      Expense(amount: 100, category: 'Food', date: may, note: note));

  test('restores trips with their people, expenses and shares', () async {
    final tripId = await addTrip('Ella');
    final json = await backup.serializeForTest();

    await db.deleteSplitterTrip(tripId);
    backup.setPendingRestoreForTest(json);
    await backup.restoreData();

    final trip = (await db.getAllSplitterTrips()).single;
    expect(trip.name, 'Ella');
    final people = await db.participantsForTrip(trip.id!);
    expect(people.map((p) => p.name), ['Asha', 'Ravi']);
    final expense = (await db.expensesForTrip(trip.id!)).single;
    expect(expense.note, 'Hotel');
    expect(expense.payerName, 'Asha');
    expect(expense.shareParticipantIds, people.map((p) => p.id));
  });

  test('restore replaces data added after the backup', () async {
    await addExpense('In backup');
    await addTrip('In backup');
    final json = await backup.serializeForTest();

    await addExpense('Added later');
    await addTrip('Added later');
    backup.setPendingRestoreForTest(json);
    await backup.restoreData();

    final expenses = await db.expensesForMonth(may);
    expect(expenses.map((e) => e.note), ['In backup']);
    final trips = await db.getAllSplitterTrips();
    expect(trips.map((t) => t.name), ['In backup']);
  });

  test('an older backup without trips keeps the trips on the phone', () async {
    await addExpense('In backup');
    final old = jsonDecode(await backup.serializeForTest())
        as Map<String, dynamic>
      ..removeWhere((table, _) => table.startsWith('splitter_'));

    await addExpense('Added later');
    await addTrip('Ella');
    backup.setPendingRestoreForTest(jsonEncode(old));
    await backup.restoreData();

    final expenses = await db.expensesForMonth(may);
    expect(expenses.map((e) => e.note), ['In backup']);
    final trip = (await db.getAllSplitterTrips()).single;
    expect(await db.expensesForTrip(trip.id!), hasLength(1));
  });

  test('a failed restore leaves existing data untouched', () async {
    await addExpense('Keep me');
    await addTrip('Ella');
    backup.setPendingRestoreForTest(jsonEncode({
      'expenses': [
        {'id': 1, 'category': 'Food', 'date': may.toIso8601String()},
      ],
    }));

    await expectLater(backup.restoreData(), throwsA(isA<DatabaseException>()));

    final expenses = await db.expensesForMonth(may);
    expect(expenses.map((e) => e.note), ['Keep me']);
    expect(await db.getAllSplitterTrips(), hasLength(1));
  });

  test('the PIN is never included in a backup', () async {
    await db.setSetting('pin_hash', hashPin('1234'));
    await db.setSetting('currency', 'Rs.');

    final json = await backup.serializeForTest();

    expect(json, isNot(contains('pin_hash')));
    expect(json, contains('currency'));
  });
}
