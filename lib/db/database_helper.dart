import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../models/custom_category.dart';
import '../models/debt.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/expense_filter.dart';
import '../models/household_item.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import '../models/savings_goal.dart';
import '../models/spending_trend.dart';
import '../models/splitter_trip.dart';
import '../models/splitter_participant.dart';
import '../models/splitter_expense.dart';
import '../services/receipt_photos.dart';

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
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            photo TEXT,
            account_id INTEGER
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
        await _createDebtTables(db);
        await _createAccountTables(db);
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
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE expenses ADD COLUMN photo TEXT');
          await _createDebtTables(db);
        }
        if (oldVersion < 7) {
          // Income may already have the column if version 5 tables were
          // created during this same upgrade.
          await _addColumnIfMissing(db, 'expenses', 'account_id', 'INTEGER');
          await _addColumnIfMissing(db, 'income', 'account_id', 'INTEGER');
          await _createAccountTables(db);
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    // No columns means no table; it is created later with the column.
    if (columns.isEmpty || columns.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<void> _createAccountTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        opening_balance REAL NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account INTEGER NOT NULL,
        to_account INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
  }

  Future<void> _createDebtTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL
      )''');
  }

  Future<void> _createMoneyTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS income(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        source TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        account_id INTEGER
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

  /// Deletes the expense and its receipt photo.
  Future<int> deleteExpense(int id) async {
    final db = await database;
    final rows = await db.query('expenses',
        columns: ['photo'], where: 'id = ?', whereArgs: [id]);
    final deleted =
        await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await ReceiptPhotos.instance.delete(rows.first['photo'] as String?);
    }
    return deleted;
  }

  // ---------- Trends ----------
  /// Spending for the [count] months ending with [lastMonth], oldest first.
  Future<List<MonthTotal>> monthlyTotals(DateTime lastMonth, int count) async {
    final db = await database;
    final start = DateTime(lastMonth.year, lastMonth.month - count + 1, 1);
    final end = DateTime(lastMonth.year, lastMonth.month + 1, 1);
    final rows = await db.rawQuery(
      'SELECT substr(date, 1, 7) AS month, SUM(amount) AS total '
      'FROM expenses WHERE date >= ? AND date < ? GROUP BY month',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return fillMonths(lastMonth, count, {
      for (final r in rows)
        r['month'] as String: (r['total'] as num).toDouble(),
    });
  }

  Future<Map<String, double>> categoryTotals(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.rawQuery(
      'SELECT category, SUM(amount) AS total FROM expenses '
      'WHERE date >= ? AND date < ? GROUP BY category',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return {
      for (final r in rows)
        r['category'] as String: (r['total'] as num).toDouble(),
    };
  }

  // ---------- Accounts ----------
  static const lastAccountKey = 'last_account_id';

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT a.*, a.opening_balance'
      ' + COALESCE((SELECT SUM(amount) FROM income'
      '     WHERE account_id = a.id), 0)'
      ' - COALESCE((SELECT SUM(amount) FROM expenses'
      '     WHERE account_id = a.id), 0)'
      ' + COALESCE((SELECT SUM(amount) FROM account_transfers'
      '     WHERE to_account = a.id), 0)'
      ' - COALESCE((SELECT SUM(amount) FROM account_transfers'
      '     WHERE from_account = a.id), 0) AS balance '
      'FROM accounts a ORDER BY a.id',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account account) async {
    final db = await database;
    return db.insert('accounts', account.toMap()..remove('id'));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return db.update('accounts', account.toMap(),
        where: 'id = ?', whereArgs: [account.id]);
  }

  /// Deletes the account and its transfers. Its expenses and income are kept
  /// but no longer belong to an account.
  Future<void> deleteAccount(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in const ['expenses', 'income']) {
        await txn.update(table, {'account_id': null},
            where: 'account_id = ?', whereArgs: [id]);
      }
      await txn.delete('account_transfers',
          where: 'from_account = ? OR to_account = ?', whereArgs: [id, id]);
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// The account new expenses and income should start with: the one used
  /// last, or the first account. Null when there are no accounts.
  Future<int?> defaultAccountId(List<Account> accounts) async {
    if (accounts.isEmpty) return null;
    final last = int.tryParse(await getSetting(lastAccountKey, ''));
    return accounts.any((a) => a.id == last) ? last : accounts.first.id;
  }

  Future<void> rememberAccount(int? id) async {
    if (id != null) await setSetting(lastAccountKey, '$id');
  }

  Future<int> insertTransfer(AccountTransfer transfer) async {
    if (transfer.fromAccount == transfer.toAccount) {
      throw ArgumentError('Cannot transfer to the same account');
    }
    final db = await database;
    return db.insert('account_transfers', transfer.toMap()..remove('id'));
  }

  Future<void> deleteTransfer(int id) async {
    final db = await database;
    await db.delete('account_transfers', where: 'id = ?', whereArgs: [id]);
  }

  /// Everything that moved money in or out of the account, newest first.
  Future<List<AccountActivity>> accountActivity(int accountId,
      {int limit = 200}) async {
    final db = await database;
    final names = {
      for (final a in await getAccounts()) a.id: a.name,
    };
    final activity = <AccountActivity>[
      for (final r in await db.query('expenses',
          where: 'account_id = ?', whereArgs: [accountId]))
        AccountActivity(
          kind: ActivityKind.expense,
          id: r['id'] as int,
          date: DateTime.parse(r['date'] as String),
          title: r['category'] as String,
          note: (r['note'] ?? '') as String,
          amount: -(r['amount'] as num).toDouble(),
        ),
      for (final r in await db.query('income',
          where: 'account_id = ?', whereArgs: [accountId]))
        AccountActivity(
          kind: ActivityKind.income,
          id: r['id'] as int,
          date: DateTime.parse(r['date'] as String),
          title: r['source'] as String,
          note: (r['note'] ?? '') as String,
          amount: (r['amount'] as num).toDouble(),
        ),
      for (final r in await db.query('account_transfers',
          where: 'from_account = ? OR to_account = ?',
          whereArgs: [accountId, accountId]))
        if (r['to_account'] == accountId)
          AccountActivity(
            kind: ActivityKind.transferIn,
            id: r['id'] as int,
            date: DateTime.parse(r['date'] as String),
            title: 'From ${names[r['from_account']] ?? 'deleted account'}',
            note: (r['note'] ?? '') as String,
            amount: (r['amount'] as num).toDouble(),
          )
        else
          AccountActivity(
            kind: ActivityKind.transferOut,
            id: r['id'] as int,
            date: DateTime.parse(r['date'] as String),
            title: 'To ${names[r['to_account']] ?? 'deleted account'}',
            note: (r['note'] ?? '') as String,
            amount: -(r['amount'] as num).toDouble(),
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return activity.take(limit).toList();
  }

  // ---------- Shopping ----------
  /// Adds bought stock to [item] and, when [cost] is given, records it as an
  /// expense. Both happen together or not at all.
  Future<void> recordPurchase(
    HouseholdItem item,
    double quantity, {
    double? cost,
    String category = 'Groceries',
    int? accountId,
    DateTime? date,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE household_items SET quantity = quantity + ? WHERE id = ?',
        [quantity, item.id],
      );
      if (cost != null && cost > 0) {
        await txn.insert(
          'expenses',
          Expense(
            amount: cost,
            category: category,
            date: date ?? DateTime.now(),
            note: 'Bought ${item.name}',
            accountId: accountId,
          ).toMap()
            ..remove('id'),
        );
      }
    });
  }

  // ---------- Lent and Borrowed ----------
  Future<List<Debt>> getDebts() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT d.*, COALESCE(SUM(p.amount), 0.0) AS paid '
      'FROM debts d '
      'LEFT JOIN debt_payments p ON p.debt_id = d.id '
      'GROUP BY d.id '
      'ORDER BY d.date DESC, d.id DESC',
    );
    return rows.map(Debt.fromMap).toList();
  }

  /// Names already used, so the form can suggest them.
  Future<List<String>> debtPeople() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT person FROM debts ORDER BY person COLLATE NOCASE');
    return rows.map((r) => r['person'] as String).toList();
  }

  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return db.insert('debts', debt.toMap()..remove('id'));
  }

  Future<int> updateDebt(Debt debt) async {
    final db = await database;
    return db.update('debts', debt.toMap(),
        where: 'id = ?', whereArgs: [debt.id]);
  }

  Future<void> deleteDebt(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('debt_payments', where: 'debt_id = ?', whereArgs: [id]);
      await txn.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<DebtPayment>> paymentsForDebt(int debtId) async {
    final db = await database;
    final rows = await db.query(
      'debt_payments',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(DebtPayment.fromMap).toList();
  }

  /// Records money paid back. Returns false, saving nothing, when it is more
  /// than what is still owed.
  Future<bool> addDebtPayment(DebtPayment payment) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT d.amount, COALESCE(SUM(p.amount), 0.0) AS paid '
        'FROM debts d LEFT JOIN debt_payments p ON p.debt_id = d.id '
        'WHERE d.id = ? GROUP BY d.id',
        [payment.debtId],
      );
      if (rows.isEmpty) return false;
      final remaining = (rows.first['amount'] as num).toDouble() -
          (rows.first['paid'] as num).toDouble();
      if (payment.amount > remaining + 0.005) return false;
      await txn.insert('debt_payments', payment.toMap()..remove('id'));
      return true;
    });
  }

  Future<void> deleteDebtPayment(int id) async {
    final db = await database;
    await db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
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
    await ReceiptPhotos.instance.deleteAll();
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
