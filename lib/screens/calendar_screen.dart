import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/spending_calendar.dart';
import 'add_expense_screen.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime month;
  final String currency;
  const CalendarScreen({
    super.key,
    required this.month,
    required this.currency,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  late DateTime month;
  Map<int, double> totals = {};
  List<Expense> expenses = [];
  int? selectedDay;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    month = DateTime(widget.month.year, widget.month.month);
    final now = DateTime.now();
    if (now.year == month.year && now.month == month.month) {
      selectedDay = now.day;
    }
    _load();
  }

  Future<void> _load() async {
    final t = await db.dailyTotals(month);
    final e = await db.expensesForMonth(month);
    if (!mounted) return;
    setState(() {
      totals = t;
      expenses = e;
      loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selectedDay = null;
    });
    _load();
  }

  Future<void> _edit(Expense e) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: e)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = totals.values.fold<double>(0, (s, v) => s + v);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous month',
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next month',
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                Text(
                  'Spent ${widget.currency} ${money.format(total)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.outline, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _weekdayHeader(cs),
                const SizedBox(height: 4),
                _grid(cs),
                const SizedBox(height: 16),
                ..._dayDetails(cs),
              ],
            ),
    );
  }

  Widget _weekdayHeader(ColorScheme cs) {
    // 2024-01-01 was a Monday.
    final names = [
      for (var i = 0; i < 7; i++)
        DateFormat('E').format(DateTime(2024, 1, 1 + i)).substring(0, 2),
    ];
    return Row(
      children: [
        for (final n in names)
          Expanded(
            child: Text(
              n,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.outline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(ColorScheme cs) {
    final blanks = leadingBlankDays(month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final max = totals.values.fold<double>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.82,
      children: [
        for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
        for (var day = 1; day <= days; day++)
          _dayCell(
            day,
            totals[day] ?? 0,
            heatLevel(totals[day] ?? 0, max),
            isToday:
                now.year == month.year &&
                now.month == month.month &&
                now.day == day,
            cs: cs,
          ),
      ],
    );
  }

  Widget _dayCell(
    int day,
    double total,
    double level, {
    required bool isToday,
    required ColorScheme cs,
  }) {
    final selected = selectedDay == day;
    // Strong shading needs light text to stay readable.
    final onShade = level > 0.55 ? cs.onPrimary : cs.onSurface;
    return Semantics(
      button: true,
      label:
          '${DateFormat('d MMMM').format(DateTime(month.year, month.month, day))}, '
          '${total > 0 ? 'spent ${widget.currency} ${money.format(total)}' : 'no spending'}',
      child: InkWell(
        onTap: () => setState(() => selectedDay = day),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: level > 0
                ? cs.primary.withValues(alpha: 0.12 + level * 0.78)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? cs.tertiary
                  : isToday
                  ? cs.primary
                  : Colors.transparent,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: level > 0 ? onShade : cs.onSurface,
                  ),
                ),
                if (total > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      compactAmount(total),
                      style: TextStyle(fontSize: 11, color: onShade),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dayDetails(ColorScheme cs) {
    final day = selectedDay;
    if (day == null) {
      return [
        Text(
          'Tap a day to see its expenses',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.outline, fontSize: 13),
        ),
      ];
    }
    final date = DateTime(month.year, month.month, day);
    final dayExpenses = expenses.where((e) => e.date.day == day).toList();
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE, d MMMM').format(date),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${widget.currency} ${money.format(totals[day] ?? 0)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (dayExpenses.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No expenses on this day',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outline),
          ),
        )
      else
        for (final e in dayExpenses)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              onTap: () => _edit(e),
              leading: Icon(
                categoryByName(e.category).icon,
                color: categoryByName(e.category).color,
              ),
              title: Text(e.category),
              subtitle: e.note.isEmpty
                  ? null
                  : Text(e.note, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                '${widget.currency} ${money.format(e.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
    ];
  }
}
