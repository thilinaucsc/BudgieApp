import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/expense_category.dart';
import '../models/household_item.dart';
import '../models/shopping.dart';
import 'account_field.dart';
import 'add_item_screen.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen>
    with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;
  List<HouseholdItem> items = [];
  List<Account> accounts = [];
  String currency = 'Rs.';
  bool loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await db.getAllItems();
    final a = await db.getAccounts();
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      items = data;
      accounts = a;
      currency = c;
      loading = false;
    });
  }

  Future<void> _shareList(BuildContext buttonContext) async {
    // iPad anchors the share sheet to the button that opened it.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await Share.share(
      shoppingListText(lowItems),
      subject: 'Shopping list',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _markBought(HouseholdItem item) async {
    final initialAccount = await db.defaultAccountId(accounts);
    if (!mounted) return;
    final result = await showModalBottomSheet<_Purchase>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BoughtSheet(
        item: item,
        currency: currency,
        accounts: accounts,
        initialAccount: initialAccount,
      ),
    );
    if (result == null) return;
    await db.recordPurchase(
      item,
      result.quantity,
      cost: result.cost,
      category: result.category,
      accountId: result.accountId,
    );
    if (result.cost != null) await db.rememberAccount(result.accountId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.cost == null
              ? 'Added ${formatQuantity(result.quantity)} ${item.unit} to ${item.name}'
              : 'Added ${formatQuantity(result.quantity)} ${item.unit} to '
                    '${item.name} and recorded the expense',
        ),
      ),
    );
  }

  List<HouseholdItem> get lowItems => items.where((i) => i.isLow).toList();

  Future<void> _openForm([HouseholdItem? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(item: item)),
    );
    if (changed == true) _load();
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete this item?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Household',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'All Items'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Buy List'),
                  if (lowItems.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Badge(label: Text('${lowItems.length}')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add item',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_itemList(items), _buyList()],
            ),
    );
  }

  Widget _itemList(List<HouseholdItem> list) {
    if (list.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add household items',
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: list.length,
      itemBuilder: (_, i) => _itemTile(list[i]),
    );
  }

  Widget _buyList() {
    if (lowItems.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 72,
              color: cs.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Everything is stocked up!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tap the cart when you buy something',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
              ),
              Builder(
                builder: (buttonContext) => TextButton.icon(
                  onPressed: () => _shareList(buttonContext),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share list'),
                ),
              ),
            ],
          ),
        ),
        for (final item in lowItems) _itemTile(item, highlight: true),
      ],
    );
  }

  Widget _itemTile(HouseholdItem item, {bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = item.isLow ? cs.error : cs.primary;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Container(
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        await db.deleteItem(item.id!);
        _load();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        color: highlight ? cs.errorContainer.withValues(alpha: 0.35) : null,
        child: InkWell(
          onTap: () => _openForm(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (item.isLow) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Low',
                                style: TextStyle(
                                  color: cs.onError,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Stock: ${_fmt(item.quantity)} ${item.unit}  ·  Min: ${_fmt(item.minQuantity)} ${item.unit}',
                        style: TextStyle(color: cs.outline, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (highlight)
                  IconButton(
                    icon: Icon(
                      Icons.add_shopping_cart_rounded,
                      color: cs.primary,
                    ),
                    tooltip: 'Mark ${item.name} as bought',
                    onPressed: () => _markBought(item),
                  ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Record usage',
                  onPressed: () => _useItem(item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _useItem(HouseholdItem item) async {
    final controller = TextEditingController(text: '1');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How much did you use?',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(suffixText: item.unit),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Use'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final used = double.tryParse(controller.text) ?? 0;
    if (used <= 0) return;
    item.quantity = (item.quantity - used).clamp(0, double.infinity);
    await db.updateItem(item);
    _load();
  }

  String _fmt(double v) => formatQuantity(v);
}

class _Purchase {
  final double quantity;
  final double? cost;
  final String category;
  final int? accountId;

  const _Purchase(this.quantity, this.cost, this.category, this.accountId);
}

class _BoughtSheet extends StatefulWidget {
  final HouseholdItem item;
  final String currency;
  final List<Account> accounts;
  final int? initialAccount;

  const _BoughtSheet({
    required this.item,
    required this.currency,
    required this.accounts,
    required this.initialAccount,
  });

  @override
  State<_BoughtSheet> createState() => _BoughtSheetState();
}

class _BoughtSheetState extends State<_BoughtSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  final _cost = TextEditingController();
  String _category = 'Groceries';
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: formatQuantity(suggestedPurchase(widget.item)),
    );
    _accountId = widget.initialAccount;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final cost = _cost.text.trim();
    Navigator.pop(
      context,
      _Purchase(
        double.parse(_quantity.text.trim()),
        cost.isEmpty ? null : double.parse(cost),
        _category,
        _accountId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCost = _cost.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bought ${widget.item.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantity,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'How much',
                  suffixText: widget.item.unit,
                ),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  return value == null || value <= 0
                      ? 'Enter an amount greater than 0'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Cost (optional)',
                  prefixText: '${widget.currency} ',
                  helperText: 'Adds an expense when filled in',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final value = double.tryParse(t);
                  return value == null || value <= 0
                      ? 'Enter an amount greater than 0'
                      : null;
                },
              ),
              if (hasCost) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoryByName(_category).name,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.name,
                        child: Row(
                          children: [
                            Icon(c.icon, color: c.color, size: 20),
                            const SizedBox(width: 12),
                            Text(c.name),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Add to stock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
