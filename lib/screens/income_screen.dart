import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/income.dart';
import 'add_income_screen.dart';

class IncomeScreen extends StatefulWidget {
  final DateTime month;
  const IncomeScreen({super.key, required this.month});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  late DateTime month;
  List<Income> items = [];
  MonthlyBalance balance =
      const MonthlyBalance(income: 0, spent: 0, saved: 0);
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    month = widget.month;
    _load();
  }

  Future<void> _load() async {
    final i = await db.incomeForMonth(month);
    final b = await db.monthlyBalance(month);
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      items = i;
      balance = b;
      currency = c;
      loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() => month = DateTime(month.year, month.month + delta));
    _load();
  }

  // New income defaults to today, or the 1st when viewing another month.
  DateTime get _defaultDate {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month ? now : month;
  }

  Future<void> _openForm([Income? income]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddIncomeScreen(
          income: income,
          currency: currency,
          initialDate: _defaultDate,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this income?'),
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
      appBar: AppBar(title: const Text('Income')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add income',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous month',
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next month',
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                _summary(cs),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No income this month. Tap + to add your salary or '
                      'other money you received.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.outline, fontSize: 14),
                    ),
                  )
                else
                  for (final i in items) _item(i, cs),
              ],
            ),
    );
  }

  Widget _summary(ColorScheme cs) {
    Widget line(String label, double value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight:
                            strong ? FontWeight.w700 : FontWeight.normal)),
              ),
              const SizedBox(width: 12),
              Text(
                '${value < 0 ? '-' : ''}$currency ${money.format(value.abs())}',
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                  color: strong && value < 0 ? cs.error : null,
                ),
              ),
            ],
          ),
        );
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            line('Income', balance.income),
            line('Expenses', balance.spent),
            line('Moved to savings goals', balance.saved),
            const Divider(height: 16),
            line('Left this month', balance.left, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _item(Income income, ColorScheme cs) {
    final icon = incomeSources[income.source] ?? Icons.more_horiz;
    final detail = [
      DateFormat('d MMM').format(income.date),
      if (income.note.isNotEmpty) income.note,
    ].join(' · ');
    return Dismissible(
      key: ValueKey(income.id),
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
          child:
              Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        setState(() => items.removeWhere((x) => x.id == income.id));
        await db.deleteIncome(income.id!);
        _load();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: ListTile(
          onTap: () => _openForm(income),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          title: Text(income.source),
          subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(
            '$currency ${money.format(income.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
