import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense_category.dart';
import '../models/recurring_expense.dart';

class AddRecurringScreen extends StatefulWidget {
  final RecurringExpense? recurring;
  final String currency;
  const AddRecurringScreen({super.key, this.recurring, required this.currency});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends State<AddRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _category;
  late RecurringFrequency _frequency;
  late DateTime _nextDue;
  late final DateTime _initialDue;

  bool get isEdit => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;
    final now = DateTime.now();
    _amount =
        TextEditingController(text: r == null ? '' : r.amount.toString());
    _note = TextEditingController(text: r?.note ?? '');
    _category = categoryByName(r?.category ?? categories.first.name).name;
    _frequency = r?.frequency ?? RecurringFrequency.monthly;
    _initialDue = r?.upcomingDue(now) ?? DateTime(now.year, now.month, now.day);
    _nextDue = _initialDue;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextDue = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.recurring;
    // Keep the original anchor unless the schedule itself was changed.
    final keepAnchor = existing != null &&
        _nextDue == _initialDue &&
        _frequency == existing.frequency;
    final recurring = RecurringExpense(
      id: existing?.id,
      amount: double.parse(_amount.text.trim()),
      category: _category,
      note: _note.text.trim(),
      frequency: _frequency,
      startDate: keepAnchor ? existing.startDate : _nextDue,
      nextDue: _nextDue,
      active: existing?.active ?? true,
    );
    final db = DatabaseHelper.instance;
    if (isEdit) {
      await db.updateRecurringExpense(recurring);
    } else {
      await db.insertRecurringExpense(recurring);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit recurring expense' : 'Add recurring expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amount,
              autofocus: !isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
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
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.name,
                    child: Row(
                      children: [
                        Icon(c.icon, color: c.color, size: 20),
                        const SizedBox(width: 12),
                        Text(c.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 20),
            Text(
              'Repeats',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<RecurringFrequency>(
              showSelectedIcon: false,
              segments: [
                for (final f in RecurringFrequency.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Next payment: '
                        '${DateFormat('d MMMM yyyy').format(_nextDue)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 16, color: cs.outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Rent, Netflix, electricity...',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Save recurring expense'),
            ),
          ],
        ),
      ),
    );
  }
}
