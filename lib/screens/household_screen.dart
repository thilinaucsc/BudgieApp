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
        title: const Text('Household'),
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
                    Badge(
                      label: Text('${lowItems.length}'),
                    ),
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
      return const Center(
          child: Text('No items yet. Tap + to add household items.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: list.length,
      itemBuilder: (_, i) => _itemTile(list[i]),
    );
  }

  Widget _buyList() {
    if (lowItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text('Everything is stocked up!',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: lowItems.length,
      itemBuilder: (_, i) => _itemTile(lowItems[i], highlight: true),
    );
  }

  Widget _itemTile(HouseholdItem item, {bool highlight = false}) {
    final color = item.isLow ? Colors.red : Colors.teal;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        await db.deleteItem(item.id!);
        _load();
      },
      child: ListTile(
        tileColor: highlight ? Colors.red.withAlpha(15) : null,
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(Icons.inventory_2_outlined, color: color),
        ),
        title: Text(item.name,
            style: TextStyle(
                fontWeight:
                    item.isLow ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(
          'Stock: ${_fmt(item.quantity)} ${item.unit}  •  Min: ${_fmt(item.minQuantity)} ${item.unit}',
        ),
        trailing: _itemTileTrailing(item),
        onTap: () => _openForm(item),
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
          left: 24, right: 24, top: 24,
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
              decoration: InputDecoration(
                suffixText: item.unit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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

  Widget _itemTileTrailing(HouseholdItem item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isLow)
            const Chip(
              label: Text('Low', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
              padding: EdgeInsets.zero,
            ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Record usage',
            onPressed: () => _useItem(item),
          ),
        ],
      );

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
