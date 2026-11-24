class MonthTotal {
  final DateTime month;
  final double total;
  const MonthTotal(this.month, this.total);
}

class CategoryChange {
  final String category;
  final double current;
  final double previous;
  const CategoryChange(this.category, this.current, this.previous);

  double get change => current - previous;
}

/// Totals for the [count] months ending with [lastMonth], oldest first.
/// [totals] is keyed by "yyyy-MM"; months with no spending show as zero.
List<MonthTotal> fillMonths(
    DateTime lastMonth, int count, Map<String, double> totals) {
  return [
    for (var i = count - 1; i >= 0; i--)
      () {
        final month = DateTime(lastMonth.year, lastMonth.month - i);
        final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        return MonthTotal(month, totals[key] ?? 0);
      }(),
  ];
}

/// Every category spent on in either month, biggest increase first.
List<CategoryChange> categoryChanges(
    Map<String, double> current, Map<String, double> previous) {
  return [
    for (final category in {...current.keys, ...previous.keys})
      CategoryChange(
          category, current[category] ?? 0, previous[category] ?? 0),
  ]..sort((a, b) => b.change.compareTo(a.change));
}

/// Percentage change from [previous] to [current], or null when there was
/// nothing to compare against.
double? percentChange(double current, double previous) =>
    previous <= 0 ? null : (current - previous) / previous * 100;
