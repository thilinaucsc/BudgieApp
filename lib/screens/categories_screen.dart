import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/custom_category.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final db = DatabaseHelper.instance;

  List<CustomCategory> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await db.getCustomCategories();
    if (!mounted) return;
    setState(() {
      items = c;
      loading = false;
    });
  }

  Future<void> _openForm([CustomCategory? category]) async {
    final result = await showDialog<CustomCategory>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    if (result == null) return;
    if (category == null) {
      await db.insertCustomCategory(result);
    } else {
      await db.updateCustomCategory(result, category.name);
    }
    _load();
  }

  Future<void> _delete(CustomCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
            'Its expenses will move to Other and its budget will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.deleteCustomCategory(category);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add category',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _emptyState(cs)
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 88),
                  children: [for (final c in items) _item(c)],
                ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'No custom categories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your own, such as Pets or Fuel',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(CustomCategory category) {
    final cat = category.toCategory();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        onTap: () => _openForm(category),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cat.color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(cat.icon, color: cat.color, size: 22),
        ),
        title: Text(cat.name),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Delete ${cat.name}',
          onPressed: () => _delete(category),
        ),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CustomCategory? category;
  const _CategoryDialog({this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _iconKey;
  late int _color;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _iconKey = c?.iconKey ?? categoryIconChoices.keys.first;
    _color = c?.colorValue ?? categoryColorChoices[6].toARGB32();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustomCategory(
        id: widget.category?.id,
        name: _name.text.trim(),
        iconKey: _iconKey,
        colorValue: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedColor = Color(_color);
    return AlertDialog(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: widget.category == null,
                  maxLength: 20,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => categoryNameError(v ?? '',
                      current: widget.category?.name),
                ),
                const SizedBox(height: 8),
                const Text('Icon',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in categoryIconChoices.entries)
                      InkWell(
                        onTap: () => setState(() => _iconKey = entry.key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: entry.key == _iconKey
                                ? selectedColor.withAlpha(40)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: entry.key == _iconKey
                                  ? selectedColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            size: 20,
                            color: entry.key == _iconKey
                                ? selectedColor
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Colour',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in categoryColorChoices)
                      InkWell(
                        onTap: () =>
                            setState(() => _color = color.toARGB32()),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: color.toARGB32() == _color
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
