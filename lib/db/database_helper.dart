import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/custom_category.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/expense_filter.dart';
import '../models/household_item.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import '../models/savings_goal.dart';
import '../models/splitter_trip.dart';
import '../models/splitter_participant.dart';
import '../models/splitter_expense.dart';

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
      version: 5,
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
        await db.execute('''
          CREATE TABLE splitter_trips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE splitter_participants(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            name TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE splitter_expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            payer_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE splitter_expense_shares(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expense_id INTEGER NOT NULL,
            participant_id INTEGER NOT NULL
          )''');
        await _createPlanningTables(db);
        await _createMoneyTables(db);
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
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS splitter_trips(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS splitter_participants(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              name TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS splitter_expenses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              payer_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              date TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS splitter_expense_shares(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expense_id INTEGER NOT NULL,
              participant_id INTEGER NOT NULL
            )''');
        }
        if (oldVersion < 4) {
          await _createPlanningTables(db);
        }
        if (oldVersion < 5) {
          await _createMoneyTables(db);
        }
      },
    );
  }

  Future<void> _createMoneyTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS income(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        source TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        target_date TEXT,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings_contributions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon_key TEXT NOT NULL,
        color INTEGER NOT NULL
      )''');
  }

  Future<void> _createPlanningTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        next_due TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_budgets(
        category TEXT PRIMARY KEY,
        limit_amount REAL NOT NULL
      )''');
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

  Future<List<Expense>> searchExpenses(ExpenseFilter filter) async {
    final db = await database;
    final (where, args) = filter.toWhere();
    final rows = await db.query(
      'expenses',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  // ---------- Recurring Expenses ----------
  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;
    final rows = await db.query('recurring_expenses',
        orderBy: 'active DESC, next_due ASC, id ASC');
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<int> insertRecurringExpense(RecurringExpense r) async {
    final db = await database;
    final map = r.toMap()..remove('id');
    return db.insert('recurring_expenses', map);
  }

  Future<int> updateRecurringExpense(RecurringExpense r) async {
    final db = await database;
    return db.update('recurring_expenses', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<int> deleteRecurringExpense(int id) async {
    final db = await database;
    return db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Adds an expense for every occurrence due by [now] and returns how many
  /// were added. Runs in one transaction so an occurrence is never added twice.
  Future<int> postDueRecurringExpenses(DateTime now) async {
    final db = await database;
    final today = DateTime(now.year, now.month, now.day);
    return db.transaction((txn) async {
      final rows = await txn.query(
        'recurring_expenses',
        where: 'active = 1 AND next_due <= ?',
        whereArgs: [today.toIso8601String()],
      );
      var posted = 0;
      for (final row in rows) {
        final recurring = RecurringExpense.fromMap(row);
        final due = recurring.dueDates(now);
        if (due.isEmpty) continue;
        for (final date in due) {
          final expense = Expense(
            amount: recurring.amount,
            category: recurring.category,
            date: date,
            note: recurring.note,
          );
          await txn.insert('expenses', expense.toMap()..remove('id'));
          posted++;
        }
        await txn.update(
          'recurring_expenses',
          {
            'next_due':
                recurring.occurrenceAfter(due.last).toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [recurring.id],
        );
      }
      return posted;
    });
  }

  // ---------- Category Budgets ----------
  Future<Map<String, double>> getCategoryBudgets() async {
    final db = await database;
    final rows = await db.query('category_budgets');
    return {
      for (final r in rows)
        r['category'] as String: (r['limit_amount'] as num).toDouble(),
    };
  }

  Future<void> setCategoryBudget(String category, double amount) async {
    final db = await database;
    await db.insert(
      'category_budgets',
      {'category': category, 'limit_amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategoryBudget(String category) async {
    final db = await database;
    await db.delete('category_budgets',
        where: 'category = ?', whereArgs: [category]);
  }

  // ---------- Custom Categories ----------
  Future<List<CustomCategory>> getCustomCategories() async {
    final db = await database;
    final rows = await db.query('custom_categories',
        orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(CustomCategory.fromMap).toList();
  }

  /// Makes the saved custom categories available through [categories].
  Future<void> loadCustomCategories() async {
    final custom = await getCustomCategories();
    setCustomCategories(custom.map((c) => c.toCategory()).toList());
  }

  Future<int> insertCustomCategory(CustomCategory c) async {
    final db = await database;
    final id = await db.insert('custom_categories', c.toMap()..remove('id'));
    await loadCustomCategories();
    return id;
  }

  /// Saves [c] and moves everything filed under [oldName] to its new name.
  Future<void> updateCustomCategory(CustomCategory c, String oldName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('custom_categories', c.toMap(),
          where: 'id = ?', whereArgs: [c.id]);
      for (final table in const [
        'expenses',
        'recurring_expenses',
        'category_budgets',
      ]) {
        await txn.update(table, {'category': c.name},
            where: 'category = ?', whereArgs: [oldName]);
      }
    });
    await loadCustomCategories();
  }

  /// Deletes [c], moving its expenses to Other so no spending is lost.
  Future<void> deleteCustomCategory(CustomCategory c) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in const ['expenses', 'recurring_expenses']) {
        await txn.update(table, {'category': fallbackCategoryName},
            where: 'category = ?', whereArgs: [c.name]);
      }
      await txn.delete('category_budgets',
          where: 'category = ?', whereArgs: [c.name]);
      await txn.delete('custom_categories',
          where: 'id = ?', whereArgs: [c.id]);
    });
    await loadCustomCategories();
  }

  // ---------- Income ----------
  Future<List<Income>> incomeForMonth(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.query(
      'income',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Income.fromMap).toList();
  }

  Future<int> insertIncome(Income income) async {
    final db = await database;
    return db.insert('income', income.toMap()..remove('id'));
  }

  Future<int> updateIncome(Income income) async {
    final db = await database;
    return db.update('income', income.toMap(),
        where: 'id = ?', whereArgs: [income.id]);
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    return db.delete('income', where: 'id = ?', whereArgs: [id]);
  }

  Future<MonthlyBalance> monthlyBalance(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end = DateTime(month.year, month.month + 1, 1).toIso8601String();
    Future<double> sum(String table) async {
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0.0) AS total FROM $table '
        'WHERE date >= ? AND date < ?',
        [start, end],
      );
      return (rows.first['total'] as num).toDouble();
    }

    return MonthlyBalance(
      income: await sum('income'),
      spent: await sum('expenses'),
      saved: await sum('savings_contributions'),
    );
  }

  // ---------- Savings Goals ----------
  Future<List<SavingsGoal>> getSavingsGoals() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT g.*, COALESCE(SUM(c.amount), 0.0) AS saved, '
      'MIN(c.date) AS first_contribution '
      'FROM savings_goals g '
      'LEFT JOIN savings_contributions c ON c.goal_id = g.id '
      'GROUP BY g.id '
      'ORDER BY g.created_at DESC, g.id DESC',
    );
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<int> insertSavingsGoal(SavingsGoal goal) async {
    final db = await database;
    return db.insert('savings_goals', goal.toMap()..remove('id'));
  }

  Future<int> updateSavingsGoal(SavingsGoal goal) async {
    final db = await database;
    return db.update('savings_goals', goal.toMap(),
        where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<void> deleteSavingsGoal(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('savings_contributions',
          where: 'goal_id = ?', whereArgs: [id]);
      await txn.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<SavingsContribution>> contributionsForGoal(int goalId) async {
    final db = await database;
    final rows = await db.query(
      'savings_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(SavingsContribution.fromMap).toList();
  }

  Future<double> _goalBalance(Transaction txn, int goalId) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) AS total '
      'FROM savings_contributions WHERE goal_id = ?',
      [goalId],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Records money added or withdrawn. Returns false, saving nothing, when a
  /// withdrawal is more than the goal holds.
  Future<bool> addSavingsContribution(SavingsContribution c) async {
    final db = await database;
    return db.transaction((txn) async {
      final balance = await _goalBalance(txn, c.goalId);
      if (balance + c.amount < -0.005) return false;
      await txn.insert('savings_contributions', c.toMap()..remove('id'));
      return true;
    });
  }

  /// Removes an entry from a goal's history. Returns false, removing nothing,
  /// when that would leave the goal with less than zero.
  Future<bool> deleteSavingsContribution(SavingsContribution c) async {
    final db = await database;
    return db.transaction((txn) async {
      final balance = await _goalBalance(txn, c.goalId);
      if (balance - c.amount < -0.005) return false;
      await txn.delete('savings_contributions',
          where: 'id = ?', whereArgs: [c.id]);
      return true;
    });
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
    setCustomCategories(const []);
  }

  // ---------- Splitter Trips ----------
  Future<int> insertSplitterTrip(SplitterTrip trip) async {
    final db = await database;
    final map = trip.toMap()..remove('id');
    return db.insert('splitter_trips', map);
  }

  Future<List<SplitterTrip>> getAllSplitterTrips() async {
    final db = await database;
    final rows =
        await db.query('splitter_trips', orderBy: 'created_at DESC');
    return rows.map(SplitterTrip.fromMap).toList();
  }

  Future<void> deleteSplitterTrip(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final expenseRows = await txn.query(
        'splitter_expenses',
        columns: ['id'],
        where: 'trip_id = ?',
        whereArgs: [id],
      );
      if (expenseRows.isNotEmpty) {
        final ids = expenseRows.map((r) => r['id']).join(',');
        await txn.rawDelete(
            'DELETE FROM splitter_expense_shares WHERE expense_id IN ($ids)');
      }
      await txn.delete('splitter_expenses',
          where: 'trip_id = ?', whereArgs: [id]);
      await txn.delete('splitter_participants',
          where: 'trip_id = ?', whereArgs: [id]);
      await txn.delete('splitter_trips', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- Splitter Participants ----------
  Future<int> insertSplitterParticipant(SplitterParticipant p) async {
    final db = await database;
    final map = p.toMap()..remove('id');
    return db.insert('splitter_participants', map);
  }

  Future<List<SplitterParticipant>> participantsForTrip(int tripId) async {
    final db = await database;
    final rows = await db.query(
      'splitter_participants',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'id ASC',
    );
    return rows.map(SplitterParticipant.fromMap).toList();
  }

  // ---------- Splitter Expenses ----------
  Future<int> insertSplitterExpense(SplitterExpense e) async {
    final db = await database;
    final map = e.toMap()..remove('id');
    return db.transaction((txn) async {
      final expenseId = await txn.insert('splitter_expenses', map);
      for (final participantId in e.shareParticipantIds) {
        await txn.insert('splitter_expense_shares', {
          'expense_id': expenseId,
          'participant_id': participantId,
        });
      }
      return expenseId;
    });
  }

  Future<List<SplitterExpense>> expensesForTrip(int tripId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT e.*, p.name AS payer_name '
      'FROM splitter_expenses e '
      'JOIN splitter_participants p ON p.id = e.payer_id '
      'WHERE e.trip_id = ? '
      'ORDER BY e.date DESC, e.id DESC',
      [tripId],
    );
    final List<SplitterExpense> result = [];
    for (final row in rows) {
      final expense = SplitterExpense.fromMap(row);
      final shareRows = await db.query(
        'splitter_expense_shares',
        columns: ['participant_id'],
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      final shareIds =
          shareRows.map((r) => r['participant_id'] as int).toList();
      result.add(SplitterExpense(
        id: expense.id,
        tripId: expense.tripId,
        payerId: expense.payerId,
        amount: expense.amount,
        note: expense.note,
        date: expense.date,
        payerName: row['payer_name'] as String,
        shareParticipantIds: shareIds,
      ));
    }
    return result;
  }

  Future<void> deleteSplitterExpense(int id) async {
    final db = await database;
    await db.delete('splitter_expense_shares',
        where: 'expense_id = ?', whereArgs: [id]);
    await db.delete('splitter_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> splitterTripTotal(int tripId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) AS total '
      'FROM splitter_expenses WHERE trip_id = ?',
      [tripId],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
