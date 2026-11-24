import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/debt.dart';
import 'add_debt_screen.dart';

class DebtDetailScreen extends StatefulWidget {
  final int debtId;
  final String currency;
  const DebtDetailScreen({
    super.key,
    required this.debtId,
    required this.currency,
  });

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');
  final dates = DateFormat('d MMM yyyy');

  Debt? debt;
  List<DebtPayment> payments = [];

  String _amount(double v) => '${widget.currency} ${money.format(v)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await db.getDebts();
    final p = await db.paymentsForDebt(widget.debtId);
    if (!mounted) return;
    setState(() {
      debt = all.where((d) => d.id == widget.debtId).firstOrNull;
      payments = p;
    });
  }

  Future<void> _pay(double amount) async {
    await db.addDebtPayment(DebtPayment(
      debtId: widget.debtId,
      amount: amount,
      date: DateTime.now(),
    ));
    _load();
  }

  Future<void> _partPayment() async {
    final current = debt!;
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _PaymentDialog(
        currency: widget.currency,
        maximum: current.remaining,
        maximumLabel: _amount(current.remaining),
      ),
    );
    if (amount != null) await _pay(amount);
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDebtScreen(debt: debt, currency: widget.currency),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text('Its payment history will be deleted too.'),
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
    if (confirmed != true) return;
    await db.deleteDebt(widget.debtId);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final current = debt;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(current?.person ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: current == null ? null : _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: current == null ? null : _delete,
          ),
        ],
      ),
      body: current == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summary(current, cs),
                const SizedBox(height: 16),
                if (!current.isSettled)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _partPayment,
                          child: const Text('Part payment'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _pay(current.remaining),
                          child: const Text('Paid in full'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text(
                  'Payments',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing paid back yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.outline),
                    ),
                  )
                else
                  for (final p in payments)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.check_circle_outline,
                            color: cs.primary),
                        title: Text(_amount(p.amount),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(dates.format(p.date)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Remove payment',
                          onPressed: () async {
                            await db.deleteDebtPayment(p.id!);
                            _load();
                          },
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _summary(Debt current, ColorScheme cs) {
    final lent = current.direction == DebtDirection.lent;
    final String status;
    if (current.isSettled) {
      status = 'Paid back in full';
    } else if (lent) {
      status = '${current.person} still owes you';
    } else {
      status = 'You still owe ${current.person}';
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              current.isSettled
                  ? _amount(current.amount)
                  : _amount(current.remaining),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: current.isSettled
                    ? cs.outline
                    : (lent ? cs.primary : cs.error),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${lent ? 'You lent' : 'You borrowed'} '
              '${_amount(current.amount)} on ${dates.format(current.date)}',
              style: const TextStyle(fontSize: 13),
            ),
            if (current.note.isNotEmpty)
              Text(current.note,
                  style: TextStyle(color: cs.outline, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String currency;
  final double maximum;
  final String maximumLabel;

  const _PaymentDialog({
    required this.currency,
    required this.maximum,
    required this.maximumLabel,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Part payment'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount paid back',
            prefixText: '${widget.currency} ',
          ),
          validator: (v) {
            final value = double.tryParse((v ?? '').trim());
            if (value == null || value <= 0) {
              return 'Enter an amount greater than 0';
            }
            if (value > widget.maximum + 0.005) {
              return 'Only ${widget.maximumLabel} is left';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, double.parse(_amount.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
