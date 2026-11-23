import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/bill_reminder.dart';
import 'package:budgie/models/custom_category.dart';
import 'package:budgie/models/expense_category.dart';
import 'package:budgie/models/income.dart';
import 'package:budgie/models/recurring_expense.dart';
import 'package:budgie/models/savings_goal.dart';

void main() {
  tearDown(() => setCustomCategories(const []));

  group('custom categories', () {
    const pets = ExpenseCategory('Pets', Icons.pets, Colors.brown);

    test('appear before Other, which stays last', () {
      setCustomCategories([pets]);
      expect(categories.last.name, 'Other');
      expect(categories[categories.length - 2].name, 'Pets');
      expect(categoryByName('Pets').icon, Icons.pets);
    });

    test('unknown names still fall back to Other', () {
      expect(categoryByName('Deleted').name, 'Other');
    });

    test('names must be new, ignoring capitals and spaces', () {
      setCustomCategories([pets]);
      expect(categoryNameError('  '), isNotNull);
      expect(categoryNameError(' food '), isNotNull);
      expect(categoryNameError('PETS'), isNotNull);
      expect(categoryNameError('Fuel'), isNull);
    });

    test('a category can keep its name or change its capitals', () {
      setCustomCategories([pets]);
      expect(categoryNameError('Pets', current: 'Pets'), isNull);
      expect(categoryNameError('PETS', current: 'Pets'), isNull);
      expect(categoryNameError('Food', current: 'Pets'), isNotNull);
    });

    test('every colour choice survives saving', () {
      for (final color in categoryColorChoices) {
        final saved = CustomCategory.fromMap(CustomCategory(
          id: 1,
          name: 'Pets',
          iconKey: 'pets',
          colorValue: color.toARGB32(),
        ).toMap());
        expect(saved.toCategory().color.toARGB32(), color.toARGB32());
      }
    });
  });

  group('MonthlyBalance', () {
    test('left is income minus spending and savings', () {
      const b = MonthlyBalance(income: 1000, spent: 300, saved: 200);
      expect(b.left, 500);
    });

    test('withdrawing from savings increases what is left', () {
      const b = MonthlyBalance(income: 100, spent: 100, saved: -50);
      expect(b.left, 50);
    });
  });

  group('SavingsGoal', () {
    final now = DateTime(2026, 6, 15, 10);

    SavingsGoal goal({
      double saved = 0,
      DateTime? target,
      DateTime? first,
    }) =>
        SavingsGoal(
          name: 'Phone',
          targetAmount: 1000,
          targetDate: target,
          createdAt: DateTime(2026, 1, 1),
          saved: saved,
          firstContribution: first,
        );

    test('progress and remaining stop at the target', () {
      expect(goal(saved: 250).progress, 0.25);
      expect(goal(saved: 250).remaining, 750);
      expect(goal(saved: 1500).progress, 1);
      expect(goal(saved: 1500).remaining, 0);
      expect(goal(saved: 1000).isReached, isTrue);
    });

    test('monthly amount splits what is left over the months', () {
      final g = goal(saved: 400, target: DateTime(2026, 12, 15));
      expect(g.monthlyNeeded(now), 100);
    });

    test('an unfinished last month does not count', () {
      final g = goal(saved: 500, target: DateTime(2026, 8, 14));
      expect(g.monthlyNeeded(now), 500);
    });

    test('a date within a month asks for everything left', () {
      final g = goal(saved: 400, target: DateTime(2026, 6, 20));
      expect(g.monthlyNeeded(now), 600);
    });

    test('no monthly amount without a future date or once reached', () {
      expect(goal().monthlyNeeded(now), isNull);
      expect(goal(target: DateTime(2026, 6, 14)).monthlyNeeded(now), isNull);
      expect(goal(saved: 1000, target: DateTime(2027)).monthlyNeeded(now),
          isNull);
    });

    test('projects the finish date from the saving pace', () {
      final g = goal(saved: 100, first: DateTime(2026, 6, 5));
      expect(g.projectedFinish(now), DateTime(2026, 9, 13));
    });

    test('no projection until there is a week of history', () {
      expect(goal(saved: 100, first: DateTime(2026, 6, 10)).projectedFinish(now),
          isNull);
      expect(goal().projectedFinish(now), isNull);
    });
  });

  group('planBillReminders', () {
    RecurringExpense bill(
      DateTime due, {
      String note = 'Rent',
      bool active = true,
      RecurringFrequency frequency = RecurringFrequency.monthly,
    }) =>
        RecurringExpense(
          amount: 50000,
          category: 'Bills',
          note: note,
          frequency: frequency,
          startDate: due,
          nextDue: due,
          active: active,
        );

    List<PlannedReminder> plan(
      List<RecurringExpense> bills,
      DateTime now, {
      int daysBefore = 1,
    }) =>
        planBillReminders(
          recurring: bills,
          now: now,
          daysBefore: daysBefore,
          currency: 'Rs.',
        );

    test('reminds at 9 AM the chosen days before', () {
      final result = plan([bill(DateTime(2026, 7, 10))], DateTime(2026, 7, 1),
          daysBefore: 3);
      expect(result.first.when, DateTime(2026, 7, 7, 9));
      expect(result.first.title, 'Rent');
      expect(result.first.body, 'Rs. 50,000.00 due in 3 days');
    });

    test('wording matches the number of days', () {
      final due = bill(DateTime(2026, 7, 10));
      final now = DateTime(2026, 7, 1);
      expect(plan([due], now, daysBefore: 0).first.body, endsWith('due today'));
      expect(plan([due], now).first.body, endsWith('due tomorrow'));
    });

    test('skips a reminder time that has passed', () {
      final result =
          plan([bill(DateTime(2026, 7, 10))], DateTime(2026, 7, 9, 10));
      expect(result.first.when, DateTime(2026, 8, 9, 9));
    });

    test('bills on the 31st are reminded before the shorter month ends', () {
      final result = plan([bill(DateTime(2026, 1, 31))], DateTime(2026, 2, 1));
      expect(result.first.when, DateTime(2026, 2, 27, 9));
    });

    test('paused bills get no reminders', () {
      expect(
          plan([bill(DateTime(2026, 7, 10), active: false)],
              DateTime(2026, 7, 1)),
          isEmpty);
    });

    test('uses the category when a bill has no note', () {
      final result =
          plan([bill(DateTime(2026, 7, 10), note: '')], DateTime(2026, 7, 1));
      expect(result.first.title, 'Bills');
    });

    test('keeps the soonest reminders within the phone limit', () {
      final bills = [
        for (var i = 1; i <= 30; i++)
          bill(DateTime(2026, 7, i % 28 + 2),
              frequency: RecurringFrequency.weekly),
      ];
      final result = plan(bills, DateTime(2026, 7, 1));
      expect(result, hasLength(maxBillReminders));
      expect(result.map((r) => r.id).toSet(), hasLength(maxBillReminders));
      for (var i = 1; i < result.length; i++) {
        expect(result[i].when.isBefore(result[i - 1].when), isFalse);
      }
    });
  });
}
