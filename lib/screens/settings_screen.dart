import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  final DateTime month;
  const SettingsScreen({super.key, required this.month});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budget = TextEditingController();
  final _currency = TextEditingController();
  final db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await db.getBudget(widget.month);
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      _budget.text = b == null ? '' : b.toStringAsFixed(0);
      _currency.text = c;
    });
  }

  @override
  void dispose() {
    _budget.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final text = _budget.text.trim();
    if (text.isNotEmpty) {
      await db.setBudget(widget.month, double.parse(text));
    }
    await db.setSetting('currency', _currency.text.trim());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(widget.month);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly budget from $monthName',
                helperText: 'This budget also applies to later months until you change it.',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final value = double.tryParse(t);
                if (value == null || value <= 0) return 'Enter a number greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency symbol',
                hintText: 'Rs., \$, €',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a currency symbol' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }
}
