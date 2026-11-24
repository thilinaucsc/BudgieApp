import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/expense_category.dart';
import '../models/favourite.dart';
import 'account_field.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<Favourite> items = [];
  List<Account> accounts = [];
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await db.getFavourites();
    final a = await db.getAccounts();
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      items = f;
      accounts = a;
      currency = c;
      loading = false;
    });
  }

  Future<void> _openForm([Favourite? favourite]) async {
    final result = await showDialog<Favourite>(
      context: context,
      builder: (_) => FavouriteDialog(
        favourite: favourite,
        accounts: accounts,
        currency: currency,
      ),
    );
    if (result == null) return;
    if (favourite == null) {
      await db.insertFavourite(result);
    } else {
      await db.updateFavourite(result);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick add')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add favourite',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? _emptyState(cs)
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'These appear on the home screen. Tap one there to '
                    'add it as today\'s expense.',
                    style: TextStyle(color: cs.outline, fontSize: 13),
                  ),
                ),
                for (final f in items) _item(f, cs),
              ],
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
            Icon(Icons.bolt_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'No favourites yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Save things you pay for often, like bus fare or tea, and add '
              'them with one tap',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(Favourite f, ColorScheme cs) {
    final cat = categoryByName(f.category);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        onTap: () => _openForm(f),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cat.color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(cat.icon, color: cat.color, size: 22),
        ),
        title: Text(f.label),
        subtitle: Text('$currency ${money.format(f.amount)} · ${cat.name}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Delete ${f.label}',
          onPressed: () async {
            await db.deleteFavourite(f.id!);
            _load();
          },
        ),
      ),
    );
  }
}

class FavouriteDialog extends StatefulWidget {
  final Favourite? favourite;
  final List<Account> accounts;
  final String currency;

  const FavouriteDialog({
    super.key,
    this.favourite,
    required this.accounts,
    required this.currency,
  });

  @override
  State<FavouriteDialog> createState() => _FavouriteDialogState();
}

class _FavouriteDialogState extends State<FavouriteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _category;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final f = widget.favourite;
    _amount = TextEditingController(text: f == null ? '' : f.amount.toString());
    _note = TextEditingController(text: f?.note ?? '');
    _category = categoryByName(f?.category ?? categories.first.name).name;
    final saved = f?.accountId;
    _accountId = widget.accounts.any((a) => a.id == saved) ? saved : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Favourite(
        id: widget.favourite?.id,
        amount: double.parse(_amount.text.trim()),
        category: _category,
        note: _note.text.trim(),
        accountId: _accountId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.favourite == null ? 'New favourite' : 'Edit favourite',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _note,
                  autofocus: widget.favourite == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Bus fare, tea, parking...',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${widget.currency} ',
                  ),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').trim());
                    return value == null || value <= 0
                        ? 'Enter an amount greater than 0'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.name,
                        child: Row(
                          children: [
                            Icon(c.icon, color: c.color, size: 20),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                if (widget.accounts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AccountField(
                    accounts: widget.accounts,
                    value: _accountId,
                    label: 'Paid from',
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                ],
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
