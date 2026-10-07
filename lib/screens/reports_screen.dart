import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

class ReportsScreen extends StatefulWidget {
  final DateTime month;
  final String currency;
  const ReportsScreen({super.key, required this.month, required this.currency});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final money = NumberFormat('#,##0.00');
  late DateTime month;
  List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();
    month = widget.month;
    _load();
  }

  Future<void> _load() async {
    final e = await DatabaseHelper.instance.expensesForMonth(month);
    if (mounted) setState(() => expenses = e);
  }

  void _changeMonth(int delta) {
    setState(() => month = DateTime(month.year, month.month + delta));
    _load();
  }

  double get total => expenses.fold(0.0, (sum, e) => sum + e.amount);

  Map<String, double> get byCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  List<double> get byDay {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final list = List<double>.filled(days, 0);
    for (final e in expenses) {
      list[e.date.day - 1] += e.amount;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
              Text(
                DateFormat('MMMM yyyy').format(month),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
            ],
          ),
          Text(
            'Total: ${widget.currency} ${money.format(total)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Text('No expenses this month.', textAlign: TextAlign.center),
            )
          else ...[
            const Text('Spending by category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: _pieChart()),
            const SizedBox(height: 16),
            ..._legend(),
            const SizedBox(height: 32),
            const Text('Daily spending',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _barChart(context)),
          ],
        ],
      ),
    );
  }

  Widget _pieChart() {
    final data = byCategory;
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: data.entries.map((entry) {
          final cat = categoryByName(entry.key);
          final percent = entry.value / total * 100;
          return PieChartSectionData(
            value: entry.value,
            color: cat.color,
            radius: 60,
            title: '${percent.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _legend() {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) {
      final cat = categoryByName(entry.key);
      return ListTile(
        dense: true,
        leading: Icon(cat.icon, color: cat.color),
        title: Text(cat.name),
        trailing: Text('${widget.currency} ${money.format(entry.value)}'),
      );
    }).toList();
  }

  Widget _barChart(BuildContext context) {
    final days = byDay;
    final barColor = Theme.of(context).colorScheme.primary;
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i + 1,
              barRods: [
                BarChartRodData(
                  toY: days[i],
                  color: barColor,
                  width: 6,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day == 1 || day % 5 == 0) {
                  return Text('$day', style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
