import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/category_budget.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

class CategoryBudgetsScreen extends StatefulWidget {
  final DateTime month;
  const CategoryBudgetsScreen({super.key, required this.month});

  @override
  State<CategoryBudgetsScreen> createState() => _CategoryBudgetsScreenState();
}

class _CategoryBudgetsScreenState extends State<CategoryBudgetsScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  Map<String, double> limits = {};
  List<Expense> expenses = [];
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await db.getCategoryBudgets();
    final e = await db.expensesForMonth(widget.month);
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      limits = l;
      expenses = e;
      currency = c;
      loading = false;
    });
  }

  Future<void> _editLimit(String category) async {
    final result = await showDialog<_LimitResult>(
      context: context,
      builder: (_) => _LimitDialog(
        category: category,
        currency: currency,
        current: limits[category],
      ),
    );
    if (result == null) return;
    if (result.limit == null) {
      await db.deleteCategoryBudget(category);
    } else {
      await db.setCategoryBudget(category, result.limit!);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statuses = {
      for (final s in CategoryBudgetStatus.summarize(limits, expenses))
        s.category: s,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Category budgets')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    '${DateFormat('MMMM yyyy').format(widget.month)} · '
                    'Limits repeat every month. Tap a category to change it.',
                    style: TextStyle(color: cs.outline, fontSize: 13),
                  ),
                ),
                for (final c in categories) _row(c, statuses[c.name], cs),
              ],
            ),
    );
  }

  Widget _row(
      ExpenseCategory cat, CategoryBudgetStatus? status, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => _editLimit(cat.name),
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
                child: status == null
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              cat.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                            ),
                          ),
                          Text('Set limit',
                              style:
                                  TextStyle(color: cs.primary, fontSize: 13)),
                        ],
                      )
                    : _progress(cat, status, cs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress(
      ExpenseCategory cat, CategoryBudgetStatus status, ColorScheme cs) {
    final color = status.isOver
        ? cs.error
        : status.isNear
            ? Colors.orange
            : cs.primary;
    final remainder = status.isOver
        ? 'Over by $currency ${money.format(-status.remaining)}'
        : '$currency ${money.format(status.remaining)} left';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cat.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
            ),
            Text(
              remainder,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: status.ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$currency ${money.format(status.spent)} of '
          '$currency ${money.format(status.limit)}',
          style: TextStyle(color: cs.outline, fontSize: 12),
        ),
      ],
    );
  }
}

class _LimitResult {
  final double? limit;
  const _LimitResult(this.limit);
}

class _LimitDialog extends StatefulWidget {
  final String category;
  final String currency;
  final double? current;

  const _LimitDialog({
    required this.category,
    required this.currency,
    required this.current,
  });

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limit;

  @override
  void initState() {
    super.initState();
    _limit = TextEditingController(
        text: widget.current?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.category} budget'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _limit,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monthly limit',
            prefixText: '${widget.currency} ',
          ),
          validator: (v) {
            final value = double.tryParse((v ?? '').trim());
            if (value == null || value <= 0) {
              return 'Enter a number greater than 0';
            }
            return null;
          },
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _LimitResult(null)),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
                context, _LimitResult(double.parse(_limit.text.trim())));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
