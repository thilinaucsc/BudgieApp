import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/expense_category.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import 'account_field.dart';

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
  late bool _isIncome;
  late String _category;
  late RecurringFrequency _frequency;
  late DateTime _nextDue;
  late final DateTime _initialDue;
  List<Account> _accounts = [];
  int? _accountId;

  bool get isEdit => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;
    final now = DateTime.now();
    _amount = TextEditingController(text: r == null ? '' : r.amount.toString());
    _note = TextEditingController(text: r?.note ?? '');
    _isIncome = r?.isIncome ?? false;
    _category = _validChoice(r?.category);
    _frequency = r?.frequency ?? RecurringFrequency.monthly;
    _initialDue = r?.upcomingDue(now) ?? DateTime(now.year, now.month, now.day);
    _nextDue = _initialDue;
    _loadAccounts();
  }

  /// The categories for an expense, or the sources for income.
  List<String> get _choices => _isIncome
      ? incomeSources.keys.toList()
      : categories.map((c) => c.name).toList();

  String _validChoice(String? current) =>
      _choices.contains(current) ? current! : _choices.first;

  Future<void> _loadAccounts() async {
    final db = DatabaseHelper.instance;
    final accounts = await db.getAccounts();
    final saved = widget.recurring?.accountId;
    final id = isEdit
        ? (accounts.any((a) => a.id == saved) ? saved : null)
        : await db.defaultAccountId(accounts);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _accountId = id;
    });
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
    final keepAnchor =
        existing != null &&
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
      isIncome: _isIncome,
      accountId: _accountId,
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
    final kind = _isIncome ? 'income' : 'expense';
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit recurring $kind' : 'Add recurring $kind'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_isIncome},
                onSelectionChanged: (s) => setState(() {
                  _isIncome = s.first;
                  _category = _validChoice(_category);
                }),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amount,
              autofocus: !isEdit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              // A new key resets the field when switching expense and income.
              key: ValueKey(_isIncome),
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _isIncome ? 'Source' : 'Category',
              ),
              items: [
                for (final name in _choices)
                  DropdownMenuItem(
                    value: name,
                    child: Row(
                      children: [
                        _isIncome
                            ? Icon(
                                incomeSources[name],
                                color: cs.primary,
                                size: 20,
                              )
                            : Icon(
                                categoryByName(name).icon,
                                color: categoryByName(name).color,
                                size: 20,
                              ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_isIncome ? 'Next payday' : 'Next payment'}: '
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
            if (_accounts.isNotEmpty) ...[
              AccountField(
                accounts: _accounts,
                value: _accountId,
                label: _isIncome ? 'Paid into' : 'Paid from',
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _note,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: _isIncome
                    ? 'Salary, rent received...'
                    : 'Rent, Netflix, electricity...',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Save recurring $kind'),
            ),
          ],
        ),
      ),
    );
  }
}
