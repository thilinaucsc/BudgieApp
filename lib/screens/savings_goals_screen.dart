import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/savings_goal.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<SavingsGoal> goals = [];
  String currency = 'Rs.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await db.getSavingsGoals();
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      goals = g;
      currency = c;
      loading = false;
    });
  }

  Future<void> _addGoal() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddGoalScreen(currency: currency)),
    );
    if (changed == true) _load();
  }

  Future<void> _openGoal(SavingsGoal goal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalDetailScreen(goalId: goal.id!, currency: currency),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = goals.fold<double>(0, (sum, g) => sum + g.saved);
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        tooltip: 'Add savings goal',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : goals.isEmpty
              ? _emptyState(cs)
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 88),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Text(
                        'Total saved: $currency ${money.format(total)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final g in goals) _goalCard(g, cs),
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
            Icon(Icons.savings_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'No savings goals',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to start saving for something',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalCard(SavingsGoal goal, ColorScheme cs) {
    final percent = (goal.progress * 100).floor();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _openGoal(goal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  if (goal.isReached)
                    Icon(Icons.check_circle, size: 20, color: cs.primary)
                  else
                    Text(
                      '$percent%',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$currency ${money.format(goal.saved)} of '
                '$currency ${money.format(goal.targetAmount)}',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
