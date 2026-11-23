class SavingsGoal {
  /// Saving for less than this says too little to predict a finish date.
  static const minDaysForProjection = 7;

  final int? id;
  final String name;
  final double targetAmount;
  final DateTime? targetDate;
  final DateTime createdAt;

  // Totals worked out from the goal's contributions.
  final double saved;
  final DateTime? firstContribution;

  SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.targetDate,
    required this.createdAt,
    this.saved = 0,
    this.firstContribution,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'target_date': targetDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
        id: m['id'] as int?,
        name: m['name'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        targetDate: m['target_date'] == null
            ? null
            : DateTime.parse(m['target_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        saved: ((m['saved'] ?? 0) as num).toDouble(),
        firstContribution: m['first_contribution'] == null
            ? null
            : DateTime.parse(m['first_contribution'] as String),
      );

  double get progress => (saved / targetAmount).clamp(0.0, 1.0);
  double get remaining => saved >= targetAmount ? 0 : targetAmount - saved;
  bool get isReached => saved >= targetAmount;

  /// How much to save each month to finish by [targetDate]. Null when there is
  /// no date, the date has passed or the goal is already reached.
  double? monthlyNeeded(DateTime now) {
    final target = targetDate;
    if (target == null || isReached) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (target.isBefore(today)) return null;
    var months =
        (target.year - today.year) * 12 + target.month - today.month;
    if (target.day < today.day) months--;
    return remaining / (months < 1 ? 1 : months);
  }

  /// When the goal will be reached if saving carries on at the same pace.
  DateTime? projectedFinish(DateTime now) {
    final first = firstContribution;
    if (first == null || isReached || saved <= 0) return null;
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(first.year, first.month, first.day);
    final days = today.difference(start).inDays;
    if (days < minDaysForProjection) return null;
    final daysLeft = (remaining / (saved / days)).ceil();
    return DateTime(today.year, today.month, today.day + daysLeft);
  }
}

class SavingsContribution {
  final int? id;
  final int goalId;

  /// Positive when money is added and negative when it is withdrawn.
  final double amount;
  final DateTime date;

  SavingsContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
  });

  bool get isWithdrawal => amount < 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory SavingsContribution.fromMap(Map<String, dynamic> m) =>
      SavingsContribution(
        id: m['id'] as int?,
        goalId: m['goal_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
      );
}
