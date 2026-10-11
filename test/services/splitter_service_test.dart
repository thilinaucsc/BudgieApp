import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/splitter_participant.dart';
import 'package:budgie/models/splitter_expense.dart';
import 'package:budgie/services/splitter_service.dart';

void main() {
  final alice = SplitterParticipant(id: 1, tripId: 1, name: 'Alice');
  final bob = SplitterParticipant(id: 2, tripId: 1, name: 'Bob');
  final charlie = SplitterParticipant(id: 3, tripId: 1, name: 'Charlie');

  SplitterExpense paid(int payerId, double amount, List<int> shares) =>
      SplitterExpense(
          tripId: 1,
          payerId: payerId,
          amount: amount,
          note: '',
          date: DateTime(2026),
          shareParticipantIds: shares);

  // Test 1 – Review Focus #1
  test('no expenses returns empty list', () {
    expect(settle([alice, bob], []), isEmpty);
  });

  // Test 2 – single payer, equal split
  test('one payer two others owe equal shares', () {
    final result = settle([alice, bob, charlie], [paid(1, 300, [1, 2, 3])]);
    expect(result.length, 2);
    expect(
        result.any((s) =>
            s.from == 'Bob' && s.to == 'Alice' && (s.amount - 100).abs() < 0.01),
        isTrue);
    expect(
        result.any((s) =>
            s.from == 'Charlie' &&
            s.to == 'Alice' &&
            (s.amount - 100).abs() < 0.01),
        isTrue);
  });

  // Test 3 – minimise transactions
  test('multiple payers produces minimum transactions', () {
    // Alice pays 60 split Alice+Bob; Bob pays 60 split Bob+Charlie
    // net: Alice +30, Bob 0, Charlie -30 → 1 settlement
    final result = settle([alice, bob, charlie], [
      paid(1, 60, [1, 2]),
      paid(2, 60, [2, 3]),
    ]);
    expect(result.length, 1);
    expect(result.first.from, 'Charlie');
    expect(result.first.to, 'Alice');
    expect((result.first.amount - 30).abs(), lessThan(0.01));
  });

  // Test 4 – Review Focus #3: zero-balance participant excluded
  test('zero-net participant not in settlements', () {
    // Alice pays 100 shared only with Alice; Bob has no involvement
    final result = settle([alice, bob], [paid(1, 100, [1])]);
    expect(result, isEmpty);
  });

  // Test 5 – Review Focus #2: all expenses by one payer
  test('all expenses by one payer yields n-1 payments', () {
    final result = settle([alice, bob, charlie], [
      paid(1, 300, [1, 2, 3]),
      paid(1, 150, [1, 2, 3]),
    ]);
    // Bob owes 150, Charlie owes 150
    expect(result.length, 2);
    expect(result.every((s) => s.to == 'Alice'), isTrue);
  });
}
