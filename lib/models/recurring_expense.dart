enum RecurringFrequency {
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const RecurringFrequency(this.label);
  final String label;

  static RecurringFrequency fromName(String name) => values.firstWhere(
    (f) => f.name == name,
    orElse: () => RecurringFrequency.monthly,
  );
}

class RecurringExpense {
  final int? id;
  final double amount;
  final String category;
  final String note;
  final RecurringFrequency frequency;

  /// Anchor for the schedule. Keeps a bill on the 31st returning to the 31st
  /// after a shorter month.
  final DateTime startDate;
  final DateTime nextDue;
  final bool active;

  /// Regular income such as a salary. [category] then holds the income
  /// source, and each payment is added as income instead of an expense.
  final bool isIncome;
  final int? accountId;

  RecurringExpense({
    this.id,
    required this.amount,
    required this.category,
    this.note = '',
    required this.frequency,
    required this.startDate,
    required this.nextDue,
    this.active = true,
    this.isIncome = false,
    this.accountId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'category': category,
    'note': note,
    'frequency': frequency.name,
    'start_date': startDate.toIso8601String(),
    'next_due': nextDue.toIso8601String(),
    'active': active ? 1 : 0,
    'kind': isIncome ? 'income' : 'expense',
    'account_id': accountId,
  };

  factory RecurringExpense.fromMap(Map<String, dynamic> m) => RecurringExpense(
    id: m['id'] as int?,
    amount: (m['amount'] as num).toDouble(),
    category: m['category'] as String,
    note: (m['note'] ?? '') as String,
    frequency: RecurringFrequency.fromName(m['frequency'] as String),
    startDate: DateTime.parse(m['start_date'] as String),
    nextDue: DateTime.parse(m['next_due'] as String),
    active: (m['active'] as int) == 1,
    isIncome: m['kind'] == 'income',
    accountId: m['account_id'] as int?,
  );

  RecurringExpense copyWith({DateTime? nextDue, bool? active}) =>
      RecurringExpense(
        id: id,
        amount: amount,
        category: category,
        note: note,
        frequency: frequency,
        startDate: startDate,
        nextDue: nextDue ?? this.nextDue,
        active: active ?? this.active,
        isIncome: isIncome,
        accountId: accountId,
      );

  /// The scheduled date that follows [current].
  DateTime occurrenceAfter(DateTime current) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return DateTime(current.year, current.month, current.day + 7);
      case RecurringFrequency.monthly:
        final months =
            (current.year - startDate.year) * 12 +
            current.month -
            startDate.month +
            1;
        return _clampedDate(
          startDate.year,
          startDate.month + months,
          startDate.day,
        );
      case RecurringFrequency.yearly:
        return _clampedDate(current.year + 1, startDate.month, startDate.day);
    }
  }

  /// Every unpaid occurrence up to and including today, oldest first.
  List<DateTime> dueDates(DateTime now) {
    if (!active) return [];
    final today = DateTime(now.year, now.month, now.day);
    final due = <DateTime>[];
    var date = DateTime(nextDue.year, nextDue.month, nextDue.day);
    while (!date.isAfter(today)) {
      due.add(date);
      date = occurrenceAfter(date);
    }
    return due;
  }

  /// First occurrence on or after today. Used when resuming a paused item so
  /// the months it was paused are not charged.
  DateTime upcomingDue(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var date = DateTime(nextDue.year, nextDue.month, nextDue.day);
    while (date.isBefore(today)) {
      date = occurrenceAfter(date);
    }
    return date;
  }

  // DateTime rolls overflowing days into the next month, so cap at month end.
  static DateTime _clampedDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }
}
