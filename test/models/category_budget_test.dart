import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/category_budget.dart';
import 'package:budgie/models/expense.dart';

Expense _spend(String category, double amount) =>
    Expense(amount: amount, category: category, date: DateTime(2026, 5, 1));

void main() {
  CategoryBudgetStatus status(double spent) =>
      CategoryBudgetStatus(category: 'Food', limit: 100, spent: spent);

  test('below 80% is neither near nor over', () {
    expect(status(79.99).isNear, isFalse);
    expect(status(79.99).isOver, isFalse);
  });

  test('80% up to the limit is near', () {
    expect(status(80).isNear, isTrue);
    expect(status(100).isNear, isTrue);
    expect(status(100).isOver, isFalse);
  });

  test('above the limit is over and not near', () {
    expect(status(100.01).isOver, isTrue);
    expect(status(100.01).isNear, isFalse);
    expect(status(130).remaining, -30);
  });

  test('summarize totals each category and sorts by usage', () {
    final result = CategoryBudgetStatus.summarize(
      {'Food': 100, 'Transport': 50, 'Bills': 200},
      [
        _spend('Food', 30),
        _spend('Food', 20),
        _spend('Transport', 60),
        _spend('Shopping', 999),
      ],
    );
    expect(result.map((s) => s.category), ['Transport', 'Food', 'Bills']);
    expect(result[1].spent, 50);
    expect(result[2].spent, 0);
  });
}
