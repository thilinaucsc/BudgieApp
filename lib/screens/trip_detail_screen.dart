import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/splitter_expense.dart';
import '../models/splitter_participant.dart';
import '../models/splitter_trip.dart';
import '../services/splitter_service.dart';
import 'add_trip_expense_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final SplitterTrip trip;
  final List<SplitterParticipant> participants;

  const TripDetailScreen({
    super.key,
    required this.trip,
    required this.participants,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SplitterExpense> _expenses = [];
  bool _loading = true;
  final _repaintKey = GlobalKey();
  String _currency = 'Rs.';
  final money = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final expenses = await db.expensesForTrip(widget.trip.id!);
    final currency = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _currency = currency;
      _loading = false;
    });
  }

  List<Settlement> _settlements() => settle(widget.participants, _expenses);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.trip.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Settlements'),
          ],
        ),
      ),
      body: Column(
        children: [
          _summaryHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _expensesTab(),
                _settlementsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _summaryHeader() {
    final cs = Theme.of(context).colorScheme;
    final total = _expenses.fold<double>(0, (s, e) => s + e.amount);
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat(
            _loading ? '—' : '$_currency ${money.format(total)}',
            'Total Spent',
            cs,
          ),
          Container(width: 1, height: 28, color: cs.outlineVariant),
          _stat('${widget.participants.length}', 'People', cs),
          Container(width: 1, height: 28, color: cs.outlineVariant),
          _stat(_loading ? '—' : '${_expenses.length}', 'Expenses', cs),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: cs.outline, fontSize: 11)),
      ],
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 0) {
      return FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
      );
    }
    if (_tabController.index == 1 && _settlements().isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: _shareSettlements,
        icon: const Icon(Icons.share_outlined),
        label: const Text('Share'),
      );
    }
    return null;
  }

  Widget _expensesTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final cs = Theme.of(context).colorScheme;
    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'No expenses yet',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add one',
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _expenses.length,
      itemBuilder: (_, i) => _expenseItem(_expenses[i]),
    );
  }

  Widget _expenseItem(SplitterExpense e) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(e.id),
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
          child: Icon(
            Icons.delete_outline_rounded,
            color: cs.onErrorContainer,
          ),
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) => _deleteExpense(e),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.payerName.isEmpty ? 'Unknown' : e.payerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (e.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        e.note,
                        style:
                            TextStyle(color: cs.outline, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'split ${e.shareParticipantIds.length} ways',
                      style: TextStyle(color: cs.outline, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$_currency ${money.format(e.amount)}',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settlementsTab() {
    final cs = Theme.of(context).colorScheme;
    final settlements = _settlements();
    if (settlements.isEmpty) {
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
            const Text(
              'All even!',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RepaintBoundary(
      key: _repaintKey,
      child: Material(
        color: cs.surface,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: settlements.map((s) => _settlementCard(s)).toList(),
        ),
      ),
    );
  }

  Widget _settlementCard(Settlement s) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _avatar(s.from, cs),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.from,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: cs.outline),
            Expanded(
              child: Text(
                s.to,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _avatar(s.to, cs),
            const SizedBox(width: 12),
            Text(
              '$_currency ${money.format(s.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.primary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name, ColorScheme cs) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: cs.primaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _addExpense() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTripExpenseScreen(
          tripId: widget.trip.id!,
          participants: widget.participants,
          currency: _currency,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this expense?'),
          content: const Text('This action cannot be undone.'),
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

  Future<void> _deleteExpense(SplitterExpense e) async {
    await DatabaseHelper.instance.deleteSplitterExpense(e.id!);
    _load();
  }

  void _shareSettlements() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields_outlined),
              title: const Text('Share as text'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(_buildShareText());
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share as image'),
              onTap: () {
                Navigator.pop(ctx);
                _shareImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildShareText() {
    final settlements = _settlements();
    final totalSpent =
        _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final names = widget.participants.map((p) => p.name).join(', ');
    final buffer = StringBuffer();
    buffer.writeln('Trip: ${widget.trip.name}');
    buffer.writeln('Total: $_currency ${money.format(totalSpent)}');
    buffer.writeln('Participants: $names');
    buffer.writeln();
    buffer.writeln('Settlements:');
    for (final s in settlements) {
      buffer.writeln(
          '• ${s.from} → ${s.to}: $_currency ${money.format(s.amount)}');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _shareImage() async {
    final boundary = _repaintKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/budgie_settlement.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
