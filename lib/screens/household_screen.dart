import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/household_item.dart';
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
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
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
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household', style: TextStyle(fontWeight: FontWeight.bold)),
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
              children: [
                _itemList(items),
                _buyList(),
              ],
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
            Icon(Icons.inventory_2_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
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
            Icon(Icons.check_circle_outline_rounded, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Everything is stocked up!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: lowItems.length,
      itemBuilder: (_, i) => _itemTile(lowItems[i], highlight: true),
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
                  child: Icon(Icons.inventory_2_outlined, color: iconColor, size: 22),
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
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                          if (item.isLow) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            Text('How much did you use?',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
