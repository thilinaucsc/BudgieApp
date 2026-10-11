class SplitterExpense {
  final int? id;
  final int tripId;
  final int payerId;
  final double amount;
  final String note;
  final DateTime date;
  final String payerName;
  final List<int> shareParticipantIds;

  SplitterExpense({
    this.id,
    required this.tripId,
    required this.payerId,
    required this.amount,
    required this.note,
    required this.date,
    this.payerName = '',
    this.shareParticipantIds = const [],
  });

  /// Emits only the six stored columns (id, trip_id, payer_id, amount, note, date).
  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'payer_id': payerId,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory SplitterExpense.fromMap(Map<String, dynamic> m) => SplitterExpense(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        payerId: m['payer_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        note: (m['note'] ?? '') as String,
        date: DateTime.parse(m['date'] as String),
        payerName: '',
        shareParticipantIds: const [],
      );
}
