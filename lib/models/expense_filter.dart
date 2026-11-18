class ExpenseFilter {
  final String text;
  final String? category;
  final DateTime? from;
  final DateTime? to;
  final double? minAmount;
  final double? maxAmount;

  const ExpenseFilter({
    this.text = '',
    this.category,
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
  });

  /// SQL where clause and arguments. Null clause means no filtering.
  (String?, List<Object>) toWhere() {
    final clauses = <String>[];
    final args = <Object>[];

    final query = text.trim();
    if (query.isNotEmpty) {
      // Escape LIKE wildcards so "50%" searches for that literal text.
      final escaped = query
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      clauses.add(r"(note LIKE ? ESCAPE '\' OR category LIKE ? ESCAPE '\')");
      args.addAll(['%$escaped%', '%$escaped%']);
    }
    if (category != null) {
      clauses.add('category = ?');
      args.add(category!);
    }
    if (from != null) {
      clauses.add('date >= ?');
      args.add(DateTime(from!.year, from!.month, from!.day).toIso8601String());
    }
    if (to != null) {
      // Expenses keep their time of day, so include all of the last day.
      clauses.add('date < ?');
      args.add(
          DateTime(to!.year, to!.month, to!.day + 1).toIso8601String());
    }
    if (minAmount != null) {
      clauses.add('amount >= ?');
      args.add(minAmount!);
    }
    if (maxAmount != null) {
      clauses.add('amount <= ?');
      args.add(maxAmount!);
    }
    return (clauses.isEmpty ? null : clauses.join(' AND '), args);
  }
}
