import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/savings_goal.dart';
import 'add_goal_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final int goalId;
  final String currency;
  const GoalDetailScreen({
    super.key,
    required this.goalId,
    required this.currency,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');
  final dates = DateFormat('d MMM yyyy');

  SavingsGoal? goal;
  List<SavingsContribution> history = [];

  String _amount(double value) => '${widget.currency} ${money.format(value)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await db.getSavingsGoals();
    final h = await db.contributionsForGoal(widget.goalId);
    if (!mounted) return;
    setState(() {
      goal = goals.where((g) => g.id == widget.goalId).firstOrNull;
      history = h;
    });
  }

  Future<void> _move({required bool withdraw}) async {
    final current = goal!;
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _MoneyDialog(
        title: withdraw ? 'Withdraw money' : 'Add money',
        currency: widget.currency,
        maximum: withdraw ? current.saved : null,
        maximumLabel: _amount(current.saved),
      ),
    );
    if (amount == null) return;
    await db.addSavingsContribution(SavingsContribution(
      goalId: widget.goalId,
      amount: withdraw ? -amount : amount,
      date: DateTime.now(),
    ));
    _load();
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddGoalScreen(goal: goal, currency: widget.currency),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: const Text('Its saving history will be deleted too.'),
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
    await db.deleteSavingsGoal(widget.goalId);
    navigator.pop(true);
  }

  Future<void> _removeEntry(SavingsContribution entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = await db.deleteSavingsContribution(entry);
    if (!removed) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Remove the withdrawal first, this money was used'),
      ));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = goal;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(current?.name ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit goal',
            onPressed: current == null ? null : _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete goal',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: current.saved > 0
                            ? () => _move(withdraw: true)
                            : null,
                        icon: const Icon(Icons.remove),
                        label: const Text('Withdraw'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _move(withdraw: false),
                        icon: const Icon(Icons.add),
                        label: const Text('Add money'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing saved yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.outline),
                    ),
                  )
                else
                  for (final entry in history) _entry(entry, cs),
              ],
            ),
    );
  }

  Widget _summary(SavingsGoal current, ColorScheme cs) {
    final now = DateTime.now();
    final monthly = current.monthlyNeeded(now);
    final finish = current.projectedFinish(now);
    final target = current.targetDate;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _amount(current.saved),
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(
              'of ${_amount(current.targetAmount)}',
              style: TextStyle(color: cs.outline, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: current.progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            if (current.isReached)
              Text(
                'Goal reached!',
                style: TextStyle(
                    color: cs.primary, fontWeight: FontWeight.w700),
              )
            else ...[
              _fact('Still needed', _amount(current.remaining)),
              if (target != null) _fact('Target date', dates.format(target)),
              if (monthly != null)
                _fact('Save each month', _amount(monthly)),
              if (finish != null)
                _fact('At this pace', 'Done by ${dates.format(finish)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _entry(SavingsContribution entry, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(
          entry.isWithdrawal ? Icons.arrow_upward : Icons.arrow_downward,
          color: entry.isWithdrawal ? cs.error : cs.primary,
        ),
        title: Text(
          '${entry.isWithdrawal ? '-' : '+'}${_amount(entry.amount.abs())}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(dates.format(entry.date)),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Remove entry',
          onPressed: () => _removeEntry(entry),
        ),
      ),
    );
  }
}

class _MoneyDialog extends StatefulWidget {
  final String title;
  final String currency;
  final double? maximum;
  final String maximumLabel;

  const _MoneyDialog({
    required this.title,
    required this.currency,
    required this.maximum,
    required this.maximumLabel,
  });

  @override
  State<_MoneyDialog> createState() => _MoneyDialogState();
}

class _MoneyDialogState extends State<_MoneyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maximum = widget.maximum;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '${widget.currency} ',
          ),
          validator: (v) {
            final value = double.tryParse((v ?? '').trim());
            if (value == null || value <= 0) {
              return 'Enter an amount greater than 0';
            }
            if (maximum != null && value > maximum) {
              return 'This goal holds ${widget.maximumLabel}';
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
