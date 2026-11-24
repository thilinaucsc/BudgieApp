class Expense {
  final int? id;
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  /// File name of the attached receipt photo, kept in the app's own folder.
  final String? photo;

  /// The account the money came from, if accounts are in use.
  final int? accountId;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.photo,
    this.accountId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
        'photo': photo,
        'account_id': accountId,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        date: DateTime.parse(m['date'] as String),
        note: (m['note'] ?? '') as String,
        photo: m['photo'] as String?,
        accountId: m['account_id'] as int?,
      );
}
