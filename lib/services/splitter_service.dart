import '../models/splitter_participant.dart';
import '../models/splitter_expense.dart';

// Floating-point: owed rounded to 4dp per share, settlement to 2dp.

class Settlement {
  final String from;
  final String to;
  final double amount;

  const Settlement({
    required this.from,
    required this.to,
    required this.amount,
  });
}

List<Settlement> settle(
  List<SplitterParticipant> participants,
  List<SplitterExpense> expenses,
) {
  if (expenses.isEmpty) return [];

  // Build a map from participant id to name.
  final nameById = {for (final p in participants) p.id: p.name};

  // Compute net balance (paid - owed) for each participant.
  final Map<int, double> net = {for (final p in participants) p.id!: 0.0};

  for (final expense in expenses) {
    final shareCount = expense.shareParticipantIds.length;
    if (shareCount == 0) continue;

    // Credit the payer.
    net[expense.payerId] = (net[expense.payerId] ?? 0.0) + expense.amount;

    // Debit each share participant for their rounded portion.
    final shareAmount =
        double.parse((expense.amount / shareCount).toStringAsFixed(4));
    for (final pid in expense.shareParticipantIds) {
      net[pid] = (net[pid] ?? 0.0) - shareAmount;
    }
  }

  // Separate into creditors and debtors (ignore near-zero balances).
  final List<_Balance> creditors = [];
  final List<_Balance> debtors = [];

  for (final entry in net.entries) {
    final name = nameById[entry.key] ?? '';
    if (entry.value > 0.005) {
      creditors.add(_Balance(name, entry.value));
    } else if (entry.value < -0.005) {
      debtors.add(_Balance(name, -entry.value)); // store as positive magnitude
    }
  }

  final List<Settlement> settlements = [];

  // Greedy: pair largest-abs debtor with largest creditor.
  while (debtors.isNotEmpty && creditors.isNotEmpty) {
    // Sort descending by amount each iteration.
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final debtor = debtors.first;
    final creditor = creditors.first;

    final rawSettlement =
        debtor.amount < creditor.amount ? debtor.amount : creditor.amount;
    final settlement =
        double.parse(rawSettlement.toStringAsFixed(2));

    settlements.add(Settlement(
      from: debtor.name,
      to: creditor.name,
      amount: settlement,
    ));

    debtor.amount -= settlement;
    creditor.amount -= settlement;

    // Remove balances that are now effectively zero.
    debtors.removeWhere((b) => b.amount <= 0.005);
    creditors.removeWhere((b) => b.amount <= 0.005);
  }

  return settlements;
}

class _Balance {
  final String name;
  double amount;

  _Balance(this.name, this.amount);
}
