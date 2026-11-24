import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense_category.dart';
import '../models/spending_trend.dart';

class TrendsScreen extends StatefulWidget {
  final DateTime month;
  final String currency;
  const TrendsScreen({super.key, required this.month, required this.currency});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  int months = 6;
  List<MonthTotal> totals = [];
  List<CategoryChange> changes = [];
  bool loading = true;

  DateTime get _month => DateTime(widget.month.year, widget.month.month);
  DateTime get _lastMonth => DateTime(_month.year, _month.month - 1);

  String _amount(double v) => '${widget.currency} ${money.format(v)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await db.monthlyTotals(_month, months);
    final current = await db.categoryTotals(_month);
    final previous = await db.categoryTotals(_lastMonth);
    if (!mounted) return;
    setState(() {
      totals = t;
      changes = categoryChanges(current, previous);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Spending trends')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _comparison(cs),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Monthly spending',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 6, label: Text('6 months')),
                        ButtonSegment(value: 12, label: Text('12 months')),
                      ],
                      selected: {months},
                      onSelectionChanged: (s) {
                        setState(() => months = s.first);
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: _chart(cs)),
                const SizedBox(height: 8),
                Text(
                  'Average: ${_amount(_average)} a month',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.outline, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ..._changeList(
                  'Spending more on',
                  changes.where((c) => c.change > 0).take(3),
                  cs,
                ),
                ..._changeList(
                  'Spending less on',
                  changes.reversed.where((c) => c.change < 0).take(3),
                  cs,
                ),
              ],
            ),
    );
  }

  double get _average => totals.isEmpty
      ? 0
      : totals.fold<double>(0, (s, t) => s + t.total) / totals.length;

  Widget _comparison(ColorScheme cs) {
    final current = totals.isEmpty ? 0.0 : totals.last.total;
    final previous = totals.length < 2 ? 0.0 : totals[totals.length - 2].total;
    final percent = percentChange(current, previous);
    final up = current > previous;
    final String detail;
    if (percent == null) {
      detail = 'No spending in ${DateFormat('MMMM').format(_lastMonth)}';
    } else if (percent.abs() < 0.5) {
      detail = 'About the same as last month';
    } else {
      detail = '${percent.abs().toStringAsFixed(0)}% '
          '${up ? 'more' : 'less'} than last month';
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMMM yyyy').format(_month),
                style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_amount(current),
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (percent != null && percent.abs() >= 0.5) ...[
                  Icon(up ? Icons.trending_up : Icons.trending_down,
                      size: 18, color: up ? cs.error : cs.primary),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(detail, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            Text('Last month: ${_amount(previous)}',
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _chart(ColorScheme cs) {
    final label = DateFormat(months > 6 ? 'MMMMM' : 'MMM');
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${DateFormat('MMM yyyy').format(totals[group.x].month)}\n'
              '${_amount(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < totals.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: totals[i].total,
                  color: i == totals.length - 1
                      ? cs.primary
                      : cs.primary.withValues(alpha: 0.45),
                  width: months > 6 ? 12 : 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) => Text(
                label.format(totals[value.toInt()].month),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _changeList(
      String title, Iterable<CategoryChange> items, ColorScheme cs) {
    if (items.isEmpty) return const [];
    return [
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      for (final c in items)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            leading: Icon(categoryByName(c.category).icon,
                color: categoryByName(c.category).color),
            title: Text(c.category),
            subtitle: Text(
                '${_amount(c.previous)} last month → ${_amount(c.current)}'),
            trailing: Text(
              '${c.change > 0 ? '+' : '-'}${_amount(c.change.abs())}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: c.change > 0 ? cs.error : cs.primary,
              ),
            ),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }
}
