import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/household_item.dart';

const List<String> _units = [
  'kg', 'g', 'L', 'ml',
  'bottle', 'packet', 'box', 'can',
  'bag', 'roll', 'bar', 'piece',
];

class AddItemScreen extends StatefulWidget {
  final HouseholdItem? item;
  const AddItemScreen({super.key, this.item});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _form = GlobalKey<FormState>();
  final db = DatabaseHelper.instance;

  late TextEditingController _name;
  late TextEditingController _quantity;
  late TextEditingController _minQuantity;
  late String _unit;

  bool get isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _quantity = TextEditingController(
        text: item != null ? _fmt(item.quantity) : '');
    _minQuantity = TextEditingController(
        text: item != null ? _fmt(item.minQuantity) : '');
    final saved = item?.unit ?? 'kg';
    _unit = _units.contains(saved) ? saved : _units.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _minQuantity.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final item = HouseholdItem(
      id: widget.item?.id,
      name: _name.text.trim(),
      quantity: double.parse(_quantity.text),
      minQuantity: double.parse(_minQuantity.text),
      unit: _unit,
    );
    if (isEdit) {
      await db.updateItem(item);
    } else {
      await db.insertItem(item);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Item' : 'Add Item'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g. Rice, Milk, Shampoo',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 20),
            const Text('Unit', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _units.map((u) {
                final selected = _unit == u;
                return ChoiceChip(
                  label: Text(u),
                  selected: selected,
                  onSelected: (_) => setState(() => _unit = u),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    decoration: InputDecoration(
                      labelText: 'Current stock',
                      suffixText: _unit,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minQuantity,
                    decoration: InputDecoration(
                      labelText: 'Alert below',
                      suffixText: _unit,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Item appears in "Buy List" when current stock ≤ alert below.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
