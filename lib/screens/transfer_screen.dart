import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/account.dart';

/// Moves money between two accounts, such as withdrawing cash from the bank.
class TransferScreen extends StatefulWidget {
  final List<Account> accounts;
  final String currency;
  final int? fromAccount;

  const TransferScreen({
    super.key,
    required this.accounts,
    required this.currency,
    this.fromAccount,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _from;
  int? _to;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final ids = widget.accounts.map((a) => a.id).toList();
    _from = widget.fromAccount ?? ids.first;
    _to = ids.firstWhere((id) => id != _from, orElse: () => null);
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
    await DatabaseHelper.instance.insertTransfer(AccountTransfer(
      fromAccount: _from!,
      toAccount: _to!,
      amount: double.parse(_amount.text.trim()),
      date: _date,
      note: _note.text.trim(),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  String? _accountError(int? id) {
    if (id == null) return 'Choose an account';
    if (_from == _to) return 'Choose two different accounts';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Move money')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _picker('From', _from, (v) => setState(() => _from = v)),
            const SizedBox(height: 16),
            _picker('To', _to, (v) => setState(() => _to = v)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
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
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'ATM withdrawal, card payment...',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Move money')),
          ],
        ),
      ),
    );
  }

  Widget _picker(String label, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      validator: _accountError,
      items: [
        for (final a in widget.accounts)
          DropdownMenuItem(
            value: a.id,
            child: Row(
              children: [
                Icon(a.type.icon, size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
