import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../services/gemini_service.dart';
import '../services/mlkit_service.dart';
import '../services/premium_service.dart';
import 'premium_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;
  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _category;
  late DateTime _date;
  bool _scanning = false;

  bool get isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amount = TextEditingController(text: e == null ? '' : e.amount.toString());
    _note = TextEditingController(text: e?.note ?? '');
    _category = e?.category ?? categories.first.name;
    _date = e?.date ?? DateTime.now();
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

  Future<void> _scanBillGated() async {
    final premium = await PremiumService.instance.isPremium();
    if (!mounted) return;
    if (!premium) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
      return;
    }
    await _scanBill();
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBill() async {
    final source = await _pickSource();
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;
    setState(() => _scanning = true);
    final db = DatabaseHelper.instance;
    final key = await db.getSetting('gemini_api_key', '');
    final result = key.isNotEmpty
        ? await GeminiService(apiKey: key).extractFromReceipt(File(picked.path))
        : await MlKitService().extractFromReceipt(File(picked.path));
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read bill — try better lighting or a clearer photo.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() {
      if (result.amount != null) _amount.text = result.amount!.toStringAsFixed(2);
      if (result.date != null) _date = result.date!;
      if (result.category != null) _category = result.category!;
      if (result.note != null) _note.text = result.note!;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final expense = Expense(
      id: widget.expense?.id,
      amount: double.parse(_amount.text.trim()),
      category: _category,
      date: _date,
      note: _note.text.trim(),
    );
    final db = DatabaseHelper.instance;
    if (isEdit) {
      await db.updateExpense(expense);
    } else {
      await db.insertExpense(expense);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit expense' : 'Add expense'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Scan bill',
              onPressed: _scanBillGated,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amount,
              autofocus: !isEdit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final value = double.tryParse((v ?? '').trim());
                if (value == null || value <= 0) return 'Enter an amount greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                return ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(c.icon, size: 18, color: c.color),
                  label: Text(c.name),
                  selected: _category == c.name,
                  onSelected: (_) => setState(() => _category = c.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('EEEE, d MMMM yyyy').format(_date)),
              trailing: TextButton(onPressed: _pickDate, child: const Text('Change')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: Text(isEdit ? 'Save changes' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
