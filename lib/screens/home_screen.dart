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
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportsScreen(month: month, currency: currency),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(month: month)),
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
                _monthBar(),
                _budgetCard(),
                const Divider(height: 1),
                Expanded(child: _expenseList()),
              ],
            ),
    );
  }

  Widget _monthBar() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
        ],
      );

  Widget _budgetCard() {
    final spent = total;
    if (budget == null || budget == 0) {
      return Card(
        margin: const EdgeInsets.all(12),
        child: ListTile(
          title: Text('Spent: $currency ${money.format(spent)}'),
          subtitle: const Text('Set a monthly budget in Settings to track your limit.'),
        ),
      );
    }

    final limit = budget!;
    final ratio = spent / limit;
    final left = limit - spent;

    Color color = Colors.green;
    String? warning;
    if (ratio >= 1) {
      color = Colors.red;
      warning = 'You are over your budget.';
    } else if (ratio >= 0.8) {
      color = Colors.orange;
      warning = 'You have used 80% of your budget.';
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spent $currency ${money.format(spent)} of ${money.format(limit)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              color: color,
              backgroundColor: color.withAlpha(40),
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              left >= 0
                  ? 'Left: $currency ${money.format(left)}'
                  : 'Over by: $currency ${money.format(-left)}',
              style: TextStyle(color: color),
            ),
            if (warning != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(warning, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _expenseList() {
    if (expenses.isEmpty) {
      return const Center(child: Text('No expenses this month. Tap + to add one.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: expenses.length,
      itemBuilder: (_, i) {
        final e = expenses[i];
        final cat = categoryByName(e.category);
        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(),
          onDismissed: (_) async {
            setState(() => expenses.removeAt(i));
            await db.deleteExpense(e.id!);
            _load();
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cat.color.withAlpha(40),
              child: Icon(cat.icon, color: cat.color),
            ),
            title: Text(e.category),
            subtitle: Text(
              DateFormat('d MMM').format(e.date) + (e.note.isEmpty ? '' : '  •  ${e.note}'),
            ),
            trailing: Text(
              '$currency ${money.format(e.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _openForm(e),
          ),
        );
      },
    );
  }
}
