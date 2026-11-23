import 'package:flutter/material.dart';

const Map<String, IconData> incomeSources = {
  'Salary': Icons.payments_outlined,
  'Business': Icons.storefront_outlined,
  'Freelance': Icons.laptop_outlined,
  'Interest': Icons.account_balance_outlined,
  'Gift': Icons.card_giftcard,
  'Refund': Icons.replay,
  'Other': Icons.more_horiz,
};

class Income {
  final int? id;
  final double amount;
  final String source;
  final DateTime date;
  final String note;

  Income({
    this.id,
    required this.amount,
    required this.source,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'source': source,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Income.fromMap(Map<String, dynamic> m) => Income(
        id: m['id'] as int?,
        amount: (m['amount'] as num).toDouble(),
        source: m['source'] as String,
        date: DateTime.parse(m['date'] as String),
        note: (m['note'] ?? '') as String,
      );
}

/// Money in and out for one month. [saved] is the net amount moved into
/// savings goals, so it is negative in a month with more withdrawn than added.
class MonthlyBalance {
  final double income;
  final double spent;
  final double saved;

  const MonthlyBalance({
    required this.income,
    required this.spent,
    required this.saved,
  });

  double get left => income - spent - saved;
}
