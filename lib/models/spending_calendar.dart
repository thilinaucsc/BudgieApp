/// Days to leave blank before the 1st in a calendar whose weeks start on
/// Monday.
int leadingBlankDays(DateTime month) =>
    DateTime(month.year, month.month, 1).weekday - 1;

/// How strongly to shade a day, from 0 for no spending to 1 for the
/// month's biggest day.
double heatLevel(double total, double max) =>
    max <= 0 || total <= 0 ? 0 : (total / max).clamp(0.0, 1.0);

/// Short amounts that fit in a calendar cell: 850, 1.3k, 12k, 1.3M.
String compactAmount(double value) {
  String trim(double v) {
    final text = v.toStringAsFixed(v >= 10 ? 0 : 1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (value >= 1000000) return '${trim(value / 1000000)}M';
  if (value >= 1000) return '${trim(value / 1000)}k';
  return value.round().toString();
}
