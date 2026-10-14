import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import 'add_expense_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Expense> expenses = [];
  double? budget;
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await db.expensesForMonth(month);
    final b = await db.getBudget(month);
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      expenses = e;
      budget = b;
      currency = c;
      loading = false;
    });
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
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsScreen(month: month)),
              );
              if (changed == true) _load();
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
                      Text(
                        e.category,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15),
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
