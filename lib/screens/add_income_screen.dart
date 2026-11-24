import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/income.dart';
import 'account_field.dart';

class AddIncomeScreen extends StatefulWidget {
  final Income? income;
  final String currency;
  final DateTime initialDate;

  const AddIncomeScreen({
    super.key,
    this.income,
    required this.currency,
    required this.initialDate,
  });

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _source;
  late DateTime _date;
  List<Account> _accounts = [];
  int? _accountId;

  bool get isEdit => widget.income != null;

  Future<void> _loadAccounts() async {
    final db = DatabaseHelper.instance;
    final accounts = await db.getAccounts();
    final saved = widget.income?.accountId;
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
  void initState() {
    super.initState();
    final i = widget.income;
    _amount =
        TextEditingController(text: i == null ? '' : i.amount.toString());
    _note = TextEditingController(text: i?.note ?? '');
    _source = i?.source ?? incomeSources.keys.first;
    _date = i?.date ?? widget.initialDate;
    _loadAccounts();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final income = Income(
      id: widget.income?.id,
      amount: double.parse(_amount.text.trim()),
      source: _source,
      date: _date,
      note: _note.text.trim(),
      accountId: _accountId,
    );
    final db = DatabaseHelper.instance;
    if (isEdit) {
      await db.updateIncome(income);
    } else {
      await db.insertIncome(income);
      await db.rememberAccount(_accountId);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit income' : 'Add income')),
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
            const SizedBox(height: 20),
            Text(
              'Source',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in incomeSources.entries)
                  ChoiceChip(
                    avatar: Icon(entry.value, size: 18),
                    showCheckmark: false,
                    label: Text(entry.key),
                    selected: _source == entry.key,
                    onSelected: (_) => setState(() => _source = entry.key),
                  ),
              ],
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
                        DateFormat('EEEE, d MMMM yyyy').format(_date),
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
                label: 'Paid into',
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Save income'),
            ),
          ],
        ),
      ),
    );
  }
}
