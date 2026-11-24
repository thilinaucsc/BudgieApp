import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/expense_category.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import 'add_recurring_screen.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<RecurringExpense> items = [];
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await db.postDueRecurringExpenses(DateTime.now());
    final r = await db.getRecurringExpenses();
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      items = r;
      currency = c;
      loading = false;
    });
  }

  Future<void> _openForm([RecurringExpense? recurring]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddRecurringScreen(recurring: recurring, currency: currency),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _setActive(RecurringExpense r, bool active) async {
    final updated = active
        ? r.copyWith(active: true, nextDue: r.upcomingDue(DateTime.now()))
        : r.copyWith(active: false);
    await db.updateRecurringExpense(updated);
    _load();
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete this recurring expense?'),
      content: const Text('Expenses already added will stay in your list.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add recurring expense or income',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? _emptyState(cs)
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [for (final r in items) _item(r, cs)],
            ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_repeat_outlined,
              size: 72,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing recurring yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Add rent, bills, subscriptions or your salary once and Budgie '
              'records them when they are due',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(RecurringExpense r, ColorScheme cs) {
    final cat = r.isIncome
        ? ExpenseCategory(
            r.category,
            incomeSources[r.category] ?? Icons.payments_outlined,
            cs.primary,
          )
        : categoryByName(r.category);
    final title = r.note.isNotEmpty ? r.note : r.category;
    final schedule = r.active
        ? '${r.frequency.label} · Next ${DateFormat('d MMM yyyy').format(r.nextDue)}'
        : '${r.frequency.label} · Paused';
    return Dismissible(
      key: ValueKey(r.id),
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
          child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        setState(() => items.removeWhere((x) => x.id == r.id));
        await db.deleteRecurringExpense(r.id!);
        _load();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: InkWell(
          onTap: () => _openForm(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${r.isIncome ? '+' : ''}'
                        '$currency ${money.format(r.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        schedule,
                        style: TextStyle(color: cs.outline, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(value: r.active, onChanged: (v) => _setActive(r, v)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
