import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/debt.dart';
import 'add_debt_screen.dart';
import 'debt_detail_screen.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<Debt> debts = [];
  String currency = 'Rs.';
  bool loading = true;
  bool showSettled = false;

  String _amount(double v) => '$currency ${money.format(v)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await db.getDebts();
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      debts = d;
      currency = c;
      loading = false;
    });
  }

  Future<void> _add() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddDebtScreen(currency: currency)),
    );
    if (changed == true) _load();
  }

  Future<void> _open(Debt debt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebtDetailScreen(debtId: debt.id!, currency: currency),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final open = debts.where((d) => !d.isSettled).toList();
    final settled = debts.where((d) => d.isSettled).toList();
    final summary = DebtSummary.from(debts);
    return Scaffold(
      appBar: AppBar(title: const Text('Lent and borrowed')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Add lent or borrowed money',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : debts.isEmpty
              ? _emptyState(cs)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    Row(
                      children: [
                        _total('Owed to you', summary.owedToYou, cs.primary),
                        const SizedBox(width: 12),
                        _total('You owe', summary.youOwe, cs.error),
                      ],
                    ),
                    if (summary.people.isNotEmpty) ...[
                      _heading('By person', cs),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final p in summary.people)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  child: Text(p.person[0].toUpperCase()),
                                ),
                                title: Text(p.person),
                                trailing: Text(
                                  p.net > 0
                                      ? 'Owes you ${_amount(p.net)}'
                                      : 'You owe ${_amount(-p.net)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: p.net > 0 ? cs.primary : cs.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (open.isNotEmpty) _heading('Not paid back', cs),
                    for (final d in open) _item(d, cs),
                    if (settled.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setState(() => showSettled = !showSettled),
                        child: Text(showSettled
                            ? 'Hide paid back (${settled.length})'
                            : 'Show paid back (${settled.length})'),
                      ),
                    if (showSettled)
                      for (final d in settled) _item(d, cs),
                  ],
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
            Icon(Icons.handshake_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'Nothing lent or borrowed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to keep track of money you lend or borrow',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _total(String label, double value, Color color) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _amount(value),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text, ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: cs.outline),
        ),
      );

  Widget _item(Debt d, ColorScheme cs) {
    final lent = d.direction == DebtDirection.lent;
    final color = d.isSettled ? cs.outline : (lent ? cs.primary : cs.error);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        onTap: () => _open(d),
        leading: Icon(
          lent ? Icons.call_made_rounded : Icons.call_received_rounded,
          color: color,
        ),
        title: Text(d.person, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            lent ? 'You lent' : 'You borrowed',
            DateFormat('d MMM yyyy').format(d.date),
            if (d.note.isNotEmpty) d.note,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              d.isSettled ? 'Paid back' : _amount(d.remaining),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
            if (!d.isSettled && d.paid > 0)
              Text('of ${_amount(d.amount)}',
                  style: TextStyle(fontSize: 11, color: cs.outline)),
          ],
        ),
      ),
    );
  }
}
