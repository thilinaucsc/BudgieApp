import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/debt.dart';

class AddDebtScreen extends StatefulWidget {
  final Debt? debt;
  final String currency;
  const AddDebtScreen({super.key, this.debt, required this.currency});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _person;
  late DebtDirection _direction;
  late DateTime _date;
  List<String> _people = [];

  bool get isEdit => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _amount =
        TextEditingController(text: d == null ? '' : d.amount.toString());
    _note = TextEditingController(text: d?.note ?? '');
    _person = d?.person ?? '';
    _direction = d?.direction ?? DebtDirection.lent;
    _date = d?.date ?? DateTime.now();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final p = await DatabaseHelper.instance.debtPeople();
    if (mounted) setState(() => _people = p);
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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final debt = Debt(
      id: widget.debt?.id,
      person: _person.trim(),
      direction: _direction,
      amount: double.parse(_amount.text.trim()),
      date: _date,
      note: _note.text.trim(),
    );
    final db = DatabaseHelper.instance;
    if (isEdit) {
      await db.updateDebt(debt);
    } else {
      await db.insertDebt(debt);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paid = widget.debt?.paid ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit' : 'Add lent or borrowed')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DebtDirection>(
                showSelectedIcon: false,
                segments: [
                  for (final d in DebtDirection.values)
                    ButtonSegment(value: d, label: Text(d.label)),
                ],
                selected: {_direction},
                onSelectionChanged: (s) =>
                    setState(() => _direction = s.first),
              ),
            ),
            const SizedBox(height: 20),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _person),
              optionsBuilder: (value) {
                final typed = value.text.trim().toLowerCase();
                if (typed.isEmpty) return const [];
                return _people.where((p) =>
                    p.toLowerCase().contains(typed) &&
                    p.toLowerCase() != typed);
              },
              onSelected: (p) => _person = p,
              fieldViewBuilder: (context, controller, focusNode, _) =>
                  TextFormField(
                controller: controller,
                focusNode: focusNode,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _direction == DebtDirection.lent
                      ? 'Who did you lend to?'
                      : 'Who did you borrow from?',
                ),
                onChanged: (v) => _person = v,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
            ),
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
                if (value < paid - 0.005) {
                  return '${widget.currency} '
                      '${NumberFormat('#,##0.00').format(paid)} '
                      'is already paid back';
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
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
