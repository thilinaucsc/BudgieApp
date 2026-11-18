import 'expense.dart';

class CategoryBudgetStatus {
  /// Share of the limit at which a category starts showing a warning.
  static const nearThreshold = 0.8;

  final String category;
  final double limit;
  final double spent;

  const CategoryBudgetStatus({
    required this.category,
    required this.limit,
    required this.spent,
  });

  double get ratio => limit > 0 ? spent / limit : 0;
  double get remaining => limit - spent;
  bool get isOver => spent > limit;
  bool get isNear => !isOver && ratio >= nearThreshold;

  /// One status per limit, closest to (or furthest over) its limit first.
  static List<CategoryBudgetStatus> summarize(
    Map<String, double> limits,
    List<Expense> expenses,
  ) {
    final spent = <String, double>{};
    for (final e in expenses) {
      spent[e.category] = (spent[e.category] ?? 0) + e.amount;
    }
    return [
      for (final entry in limits.entries)
        CategoryBudgetStatus(
          category: entry.key,
          limit: entry.value,
          spent: spent[entry.key] ?? 0,
        ),
    ]..sort((a, b) => b.ratio.compareTo(a.ratio));
  }
}
