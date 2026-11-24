import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/category_budget.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/income.dart';
import '../services/reminder_service.dart';
import 'add_expense_screen.dart';
import 'category_budgets_screen.dart';
import 'income_screen.dart';
import 'reports_screen.dart';
import 'savings_goals_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Expense> expenses = [];
  double? budget;
  List<CategoryBudgetStatus> categoryAlerts = [];
  MonthlyBalance balance =
      const MonthlyBalance(income: 0, spent: 0, saved: 0);
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recurring expenses may have fallen due while the app was closed.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final posted = await db.postDueRecurringExpenses(DateTime.now());
    final e = await db.expensesForMonth(month);
    final b = await db.getBudget(month);
    final limits = await db.getCategoryBudgets();
    final m = await db.monthlyBalance(month);
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      expenses = e;
      budget = b;
      balance = m;
      categoryAlerts = CategoryBudgetStatus.summarize(limits, e)
          .where((s) => s.isOver || s.isNear)
          .toList();
      currency = c;
      loading = false;
    });
    if (posted > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(posted == 1
            ? 'Added 1 recurring expense'
            : 'Added $posted recurring expenses'),
      ));
    }
    await ReminderService.instance.sync();
  }

  Future<void> _openAndReload(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _load();
  }

  double get total => expenses.fold(0.0, (sum, e) => sum + e.amount);

  void _changeMonth(int delta) {
    setState(() => month = DateTime(month.year, month.month + delta));
    _load();
  }

  Future<void> _openForm([Expense? expense]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
    );
    if (changed == true) _load();
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this expense?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgie',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SearchScreen(currency: currency)),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart_outline_rounded),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReportsScreen(month: month, currency: currency),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsScreen(month: month)),
              );
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add expense',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _monthBar(cs),
                _budgetCard(cs),
                _balanceCard(cs),
                if (categoryAlerts.isNotEmpty) _categoryAlert(cs),
                Expanded(child: _expenseList(cs)),
              ],
            ),
    );
  }

  Widget _monthBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeMonth(-1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(ColorScheme cs) {
    final spent = total;
    final darkColor = Color.lerp(cs.primary, Colors.black, 0.25)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkColor, cs.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Spent',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$currency ${money.format(spent)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (budget != null && budget! > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (spent / budget!).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(
                  spent > budget! ? Colors.red[300]! : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget: $currency ${money.format(budget!)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12),
                ),
                Text(
                  budget! - spent >= 0
                      ? 'Left: $currency ${money.format(budget! - spent)}'
                      : 'Over: $currency ${money.format(spent - budget!)}',
                  style: TextStyle(
                    color: spent > budget!
                        ? Colors.red[200]!
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Set a budget in Settings to track your limit',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceCard(ColorScheme cs) {
    final incomeScreen = IncomeScreen(month: month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            _balanceCell('Income', balance.income, cs.primary,
                () => _openAndReload(incomeScreen)),
            _balanceCell('Saved', balance.saved, cs.onSurface,
                () => _openAndReload(const SavingsGoalsScreen())),
            _balanceCell('Left', balance.left,
                balance.left < 0 ? cs.error : cs.onSurface,
                () => _openAndReload(incomeScreen)),
          ],
        ),
      ),
    );
  }

  Widget _balanceCell(
      String label, double value, Color color, VoidCallback onTap) {
    final sign = value < 0 ? '-' : '';
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$sign$currency ${money.format(value.abs())}',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryAlert(ColorScheme cs) {
    final first = categoryAlerts.first;
    final others = categoryAlerts.length - 1;
    final state = first.isOver ? 'is over budget' : 'is close to its budget';
    final background = first.isOver ? cs.errorContainer : cs.tertiaryContainer;
    final foreground =
        first.isOver ? cs.onErrorContainer : cs.onTertiaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CategoryBudgetsScreen(month: month)),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    others > 0
                        ? '${first.category} $state, +$others more'
                        : '${first.category} $state',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expenseList(ColorScheme cs) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No expenses this month',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to record your first expense',
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Group by calendar day, newest first
    final byDate = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      byDate.putIfAbsent(d, () => []).add(e);
    }
    final sortedDates = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final date in sortedDates) ...[
          _dayHeader(date, byDate[date]!, cs),
          for (final e in byDate[date]!) _expenseItem(e, cs),
        ],
      ],
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(date);
  }

  Widget _dayHeader(
      DateTime date, List<Expense> dayExpenses, ColorScheme cs) {
    final dayTotal = dayExpenses.fold<double>(0, (s, e) => s + e.amount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text(
            _dayLabel(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.outline,
            ),
          ),
          const Spacer(),
          Text(
            '$currency ${money.format(dayTotal)}',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _expenseItem(Expense e, ColorScheme cs) {
    final cat = categoryByName(e.category);
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Container(
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Icon(Icons.delete_outline_rounded,
              color: cs.onErrorContainer),
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        setState(() => expenses.removeWhere((x) => x.id == e.id));
        await db.deleteExpense(e.id!);
        _load();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: InkWell(
          onTap: () => _openForm(e),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              e.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                            ),
                          ),
                          if (e.photo != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.photo_outlined,
                                size: 15,
                                color: cs.outline,
                                semanticLabel: 'Has receipt photo'),
                          ],
                        ],
                      ),
                      if (e.note.isNotEmpty)
                        Text(
                          e.note,
                          style:
                              TextStyle(color: cs.outline, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$currency ${money.format(e.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
