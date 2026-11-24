import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/debt.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/spending_trend.dart';

void main() {
  group('Debt', () {
    Debt debt(double amount, double paid,
            {DebtDirection direction = DebtDirection.lent,
            String person = 'Nimal'}) =>
        Debt(
          person: person,
          direction: direction,
          amount: amount,
          date: DateTime(2026, 5, 1),
          paid: paid,
        );

    test('remaining never goes below zero', () {
      expect(debt(1000, 400).remaining, 600);
      expect(debt(1000, 1000).remaining, 0);
      expect(debt(1000, 1000).isSettled, isTrue);
      expect(debt(1000, 999.99).isSettled, isFalse);
    });

    test('summary splits what you are owed from what you owe', () {
      final s = DebtSummary.from([
        debt(1000, 400),
        debt(500, 0, direction: DebtDirection.borrowed, person: 'Kamal'),
        debt(300, 300, person: 'Paid'),
      ]);
      expect(s.owedToYou, 600);
      expect(s.youOwe, 500);
      expect(s.people.map((p) => p.person), ['Nimal', 'Kamal']);
    });

    test('a person is netted across debts, ignoring capitals', () {
      final s = DebtSummary.from([
        debt(1000, 0, person: 'Nimal'),
        debt(300, 0, person: ' nimal ', direction: DebtDirection.borrowed),
      ]);
      expect(s.people.single.person, 'Nimal');
      expect(s.people.single.net, 700);
    });

    test('people who are even are left out', () {
      final s = DebtSummary.from([
        debt(200, 0),
        debt(200, 0, direction: DebtDirection.borrowed),
      ]);
      expect(s.people, isEmpty);
    });

    test('direction survives saving', () {
      final saved = Debt.fromMap(
          debt(10, 0, direction: DebtDirection.borrowed).toMap());
      expect(saved.direction, DebtDirection.borrowed);
      expect(DebtDirection.fromName('nonsense'), DebtDirection.lent);
    });
  });

  group('trends', () {
    test('missing months are filled with zero, oldest first', () {
      final result = fillMonths(DateTime(2026, 2), 4, {'2026-01': 50});
      expect(result.map((m) => m.month), [
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026, 1),
        DateTime(2026, 2),
      ]);
      expect(result.map((m) => m.total), [0, 0, 50, 0]);
    });

    test('category changes include both months, biggest rise first', () {
      final result = categoryChanges(
        {'Food': 500, 'Transport': 100},
        {'Food': 200, 'Bills': 300},
      );
      expect(result.map((c) => c.category), ['Food', 'Transport', 'Bills']);
      expect(result.map((c) => c.change), [300, 100, -300]);
    });

    test('percent change needs something to compare with', () {
      expect(percentChange(150, 100), 50);
      expect(percentChange(50, 100), -50);
      expect(percentChange(100, 0), isNull);
    });
  });

  test('expense photo survives saving and is optional', () {
    final e = Expense(
        id: 1,
        amount: 5,
        category: 'Food',
        date: DateTime(2026),
        photo: 'receipt_1.jpg');
    expect(Expense.fromMap(e.toMap()).photo, 'receipt_1.jpg');
    final old = Expense.fromMap({
      'id': 2,
      'amount': 5,
      'category': 'Food',
      'date': '2026-01-01T00:00:00.000',
      'note': '',
    });
    expect(old.photo, isNull);
  });
}
