import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/expense_filter.dart';
import 'add_expense_screen.dart';

class SearchScreen extends StatefulWidget {
  final String currency;
  const SearchScreen({super.key, required this.currency});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');
  final _query = TextEditingController();
  Timer? _debounce;
  int _searchId = 0;

  String? _category;
  DateTimeRange? _dates;
  double? _minAmount;
  double? _maxAmount;
  List<Expense> results = [];
  bool loading = true;

  bool get _hasFilters =>
      _category != null ||
      _dates != null ||
      _minAmount != null ||
      _maxAmount != null;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = ++_searchId;
    final found = await db.searchExpenses(ExpenseFilter(
      text: _query.text,
      category: _category,
      from: _dates?.start,
      to: _dates?.end,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
    ));
    // Ignore a slower, older search finishing after a newer one.
    if (!mounted || id != _searchId) return;
    setState(() {
      results = found;
      loading = false;
    });
  }

  void _onQueryChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('All categories'),
              onTap: () => Navigator.pop(c, ''),
            ),
            for (final cat in categories)
              ListTile(
                leading: Icon(cat.icon, color: cat.color),
                title: Text(cat.name),
                selected: cat.name == _category,
                onTap: () => Navigator.pop(c, cat.name),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _category = picked.isEmpty ? null : picked);
    _search();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dates,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _dates = picked);
    _search();
  }

  Future<void> _pickAmount() async {
    final picked = await showDialog<_AmountRange>(
      context: context,
      builder: (_) => _AmountDialog(
        currency: widget.currency,
        min: _minAmount,
        max: _maxAmount,
      ),
    );
    if (picked == null) return;
    setState(() {
      _minAmount = picked.min;
      _maxAmount = picked.max;
    });
    _search();
  }

  void _clearFilters() {
    setState(() {
      _category = null;
      _dates = null;
      _minAmount = null;
      _maxAmount = null;
    });
    _search();
  }

  Future<void> _open(Expense expense) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
    );
    if (changed == true) _search();
  }

  String get _dateLabel {
    final d = _dates;
    if (d == null) return 'Dates';
    final f = DateFormat('d MMM yy');
    return '${f.format(d.start)} – ${f.format(d.end)}';
  }

  String get _amountLabel {
    final f = NumberFormat('#,##0.##');
    if (_minAmount != null && _maxAmount != null) {
      return '${f.format(_minAmount)} – ${f.format(_maxAmount)}';
    }
    if (_minAmount != null) return 'From ${f.format(_minAmount)}';
    if (_maxAmount != null) return 'Up to ${f.format(_maxAmount)}';
    return 'Amount';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = results.fold<double>(0, (sum, e) => sum + e.amount);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search notes or categories',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _query.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _chip(_category ?? 'Category', _category != null, _pickCategory),
                _chip(_dateLabel, _dates != null, _pickDates),
                _chip(_amountLabel, _minAmount != null || _maxAmount != null,
                    _pickAmount),
                if (_hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          if (!loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    results.length == 1
                        ? '1 expense'
                        : '${results.length} expenses',
                    style: TextStyle(color: cs.outline, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.currency} ${money.format(total)}',
                    style: TextStyle(
                      color: cs.outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? _emptyState(cs)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: results.length,
                        itemBuilder: (_, i) => _item(results[i], cs),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 72, color: cs.outlineVariant),
          const SizedBox(height: 16),
          const Text(
            'No matching expenses',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different words or fewer filters',
            style: TextStyle(color: cs.outline, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _item(Expense e, ColorScheme cs) {
    final cat = categoryByName(e.category);
    final subtitle = [
      DateFormat('d MMM yyyy').format(e.date),
      if (e.note.isNotEmpty) e.note,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => _open(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.category,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.outline, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.currency} ${money.format(e.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountRange {
  final double? min;
  final double? max;
  const _AmountRange(this.min, this.max);
}

class _AmountDialog extends StatefulWidget {
  final String currency;
  final double? min;
  final double? max;

  const _AmountDialog({required this.currency, this.min, this.max});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(text: widget.min?.toString() ?? '');
    _max = TextEditingController(text: widget.max?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? _validateNumber(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final value = double.tryParse(t);
    return value == null || value < 0 ? 'Enter a valid amount' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Amount range'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _min,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Minimum',
                prefixText: '${widget.currency} ',
              ),
              validator: _validateNumber,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _max,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Maximum',
                prefixText: '${widget.currency} ',
              ),
              validator: (v) {
                final error = _validateNumber(v);
                if (error != null) return error;
                final min = double.tryParse(_min.text.trim());
                final max = double.tryParse((v ?? '').trim());
                if (min != null && max != null && max < min) {
                  return 'Must not be less than the minimum';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _AmountRange(
                double.tryParse(_min.text.trim()),
                double.tryParse(_max.text.trim()),
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
