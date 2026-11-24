enum DebtDirection {
  lent('I lent'),
  borrowed('I borrowed');

  const DebtDirection(this.label);
  final String label;

  static DebtDirection fromName(String name) => values.firstWhere(
        (d) => d.name == name,
        orElse: () => DebtDirection.lent,
      );
}

class Debt {
  final int? id;
  final String person;
  final DebtDirection direction;
  final double amount;
  final DateTime date;
  final String note;

  /// Total paid back so far, worked out from the debt's payments.
  final double paid;

  Debt({
    this.id,
    required this.person,
    required this.direction,
    required this.amount,
    required this.date,
    this.note = '',
    this.paid = 0,
  });

  double get remaining => paid >= amount ? 0 : amount - paid;
  bool get isSettled => amount - paid < 0.005;

  Map<String, dynamic> toMap() => {
        'id': id,
        'person': person,
        'direction': direction.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
        id: m['id'] as int?,
        person: m['person'] as String,
        direction: DebtDirection.fromName(m['direction'] as String),
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        note: (m['note'] ?? '') as String,
        paid: ((m['paid'] ?? 0) as num).toDouble(),
      );
}

class DebtPayment {
  final int? id;
  final int debtId;
  final double amount;
  final DateTime date;

  DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory DebtPayment.fromMap(Map<String, dynamic> m) => DebtPayment(
        id: m['id'] as int?,
        debtId: m['debt_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
      );
}

class PersonBalance {
  final String person;

  /// Positive when they owe you, negative when you owe them.
  final double net;

  const PersonBalance(this.person, this.net);
}

/// What is still outstanding across all unsettled debts.
class DebtSummary {
  final double owedToYou;
  final double youOwe;
  final List<PersonBalance> people;

  const DebtSummary({
    required this.owedToYou,
    required this.youOwe,
    required this.people,
  });

  factory DebtSummary.from(List<Debt> debts) {
    var owedToYou = 0.0;
    var youOwe = 0.0;
    // Group names ignoring capitals, showing the first spelling used.
    final names = <String, String>{};
    final nets = <String, double>{};
    for (final d in debts.where((d) => !d.isSettled)) {
      final signed = d.direction == DebtDirection.lent ? d.remaining : -d.remaining;
      if (signed > 0) {
        owedToYou += signed;
      } else {
        youOwe -= signed;
      }
      final key = d.person.trim().toLowerCase();
      names.putIfAbsent(key, () => d.person.trim());
      nets[key] = (nets[key] ?? 0) + signed;
    }
    final people = [
      for (final e in nets.entries)
        if (e.value.abs() >= 0.005) PersonBalance(names[e.key]!, e.value),
    ]..sort((a, b) => b.net.abs().compareTo(a.net.abs()));
    return DebtSummary(owedToYou: owedToYou, youOwe: youOwe, people: people);
  }
}
