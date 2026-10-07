import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/household_item.dart';

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// All data is stored in a local SQLite file on the phone. No internet needed.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'expenses.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT
          )''');
        await db.execute('''
          CREATE TABLE budgets(
            month TEXT PRIMARY KEY,
            limit_amount REAL NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE household_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            quantity REAL NOT NULL DEFAULT 0,
            min_quantity REAL NOT NULL DEFAULT 1,
            unit TEXT NOT NULL DEFAULT 'pcs'
          )''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS household_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              quantity REAL NOT NULL DEFAULT 0,
              min_quantity REAL NOT NULL DEFAULT 1,
              unit TEXT NOT NULL DEFAULT 'pcs'
            )''');
        }
      },
    );
  }

  // ---------- Expenses ----------
  Future<int> insertExpense(Expense e) async {
    final db = await database;
    final map = e.toMap()..remove('id');
    return db.insert('expenses', map);
  }

  Future<int> updateExpense(Expense e) async {
    final db = await database;
    return db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> expensesForMonth(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.query(
      'expenses',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  // ---------- Budgets ----------
  static String monthKey(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  /// Returns this month's budget. If none is set, uses the latest earlier
  /// budget, so the user only needs to set it once.
  Future<double?> getBudget(DateTime month) async {
    final db = await database;
    final rows = await db.query(
      'budgets',
      where: 'month <= ?',
      whereArgs: [monthKey(month)],
      orderBy: 'month DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['limit_amount'] as num).toDouble();
  }

  Future<void> setBudget(DateTime month, double amount) async {
    final db = await database;
    await db.insert(
      'budgets',
      {'month': monthKey(month), 'limit_amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- Household Items ----------
  Future<List<HouseholdItem>> getAllItems() async {
    final db = await database;
    final rows = await db.query('household_items', orderBy: 'name ASC');
    return rows.map(HouseholdItem.fromMap).toList();
  }

  Future<int> insertItem(HouseholdItem item) async {
    final db = await database;
    final map = item.toMap()..remove('id');
    return db.insert('household_items', map);
  }

  Future<int> updateItem(HouseholdItem item) async {
    final db = await database;
    return db.update('household_items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('household_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> lowStockCount() async {
    final items = await getAllItems();
    return items.where((i) => i.isLow).length;
  }

  // ---------- Settings ----------
  Future<String> getSetting(String key, String defaultValue) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return defaultValue;
    return rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> wipeAll() async {
    final db = await database;
    final path = db.path;
    await db.close();
    _db = null;
    await deleteDatabase(path);
  }
}
