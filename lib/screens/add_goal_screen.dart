import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/savings_goal.dart';

class AddGoalScreen extends StatefulWidget {
  final SavingsGoal? goal;
  final String currency;
  const AddGoalScreen({super.key, this.goal, required this.currency});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _target;
  DateTime? _targetDate;

  bool get isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name = TextEditingController(text: g?.name ?? '');
    _target = TextEditingController(
        text: g == null ? '' : g.targetAmount.toString());
    _targetDate = g?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _targetDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(today)
          ? DateTime(today.year + 1, today.month, today.day)
          : current,
      firstDate: today,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final goal = SavingsGoal(
      id: widget.goal?.id,
      name: _name.text.trim(),
      targetAmount: double.parse(_target.text.trim()),
      targetDate: _targetDate,
      createdAt: widget.goal?.createdAt ?? DateTime.now(),
    );
    final db = DatabaseHelper.instance;
    if (isEdit) {
      await db.updateSavingsGoal(goal);
    } else {
      await db.insertSavingsGoal(goal);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = _targetDate;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit goal' : 'New savings goal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What are you saving for?',
                hintText: 'New phone, holiday, emergency fund...',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target amount',
                prefixText: '${widget.currency} ',
              ),
              validator: (v) {
                final value = double.tryParse((v ?? '').trim());
                if (value == null || value <= 0) {
                  return 'Enter an amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        date == null
                            ? 'Target date (optional)'
                            : 'Target date: '
                                '${DateFormat('d MMMM yyyy').format(date)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (date != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remove target date',
                        onPressed: () => setState(() => _targetDate = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Create goal'),
            ),
          ],
        ),
      ),
    );
  }
}
