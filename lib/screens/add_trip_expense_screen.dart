import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/splitter_expense.dart';
import '../models/splitter_participant.dart';

class AddTripExpenseScreen extends StatefulWidget {
  final int tripId;
  final List<SplitterParticipant> participants;

  const AddTripExpenseScreen({
    super.key,
    required this.tripId,
    required this.participants,
  });

  @override
  State<AddTripExpenseScreen> createState() => _AddTripExpenseScreenState();
}

class _AddTripExpenseScreenState extends State<AddTripExpenseScreen> {
  final _form = GlobalKey<FormState>();
  late int _payerId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late Set<int> _involved;

  @override
  void initState() {
    super.initState();
    _payerId = widget.participants.first.id!;
    _involved = {...widget.participants.map((p) => p.id!)};
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_involved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one person')),
      );
      return;
    }
    final expense = SplitterExpense(
      tripId: widget.tripId,
      payerId: _payerId,
      amount: double.parse(_amount.text),
      note: _note.text.trim(),
      date: DateTime.now(),
      shareParticipantIds: _involved.toList(),
    );
    await DatabaseHelper.instance.insertSplitterExpense(expense);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _payerId,
              decoration: const InputDecoration(labelText: 'Who paid?'),
              items: widget.participants
                  .map(
                    (p) => DropdownMenuItem<int>(
                      value: p.id!,
                      child: Text(p.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _payerId = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (v) {
                final parsed = double.tryParse(v ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 24),
            Text(
              'Split between',
              style: TextStyle(fontSize: 13, color: cs.outline),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.participants.map((p) {
                return FilterChip(
                  label: Text(p.name),
                  selected: _involved.contains(p.id!),
                  onSelected: (v) => setState(
                    () => v ? _involved.add(p.id!) : _involved.remove(p.id!),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
