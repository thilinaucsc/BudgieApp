import 'expense.dart';

/// A saved expense, such as a daily bus fare, that can be added in one tap.
class Favourite {
  final int? id;
  final double amount;
  final String category;
  final String note;
  final int? accountId;

  const Favourite({
    this.id,
    required this.amount,
    required this.category,
    this.note = '',
    this.accountId,
  });

  String get label => note.isNotEmpty ? note : category;

  Expense toExpense(DateTime date, {int? accountId}) => Expense(
    amount: amount,
    category: category,
    date: date,
    note: note,
    accountId: accountId,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'category': category,
    'note': note,
    'account_id': accountId,
  };

  factory Favourite.fromMap(Map<String, dynamic> m) => Favourite(
    id: m['id'] as int?,
    amount: (m['amount'] as num).toDouble(),
    category: m['category'] as String,
    note: (m['note'] ?? '') as String,
    accountId: m['account_id'] as int?,
  );
}
