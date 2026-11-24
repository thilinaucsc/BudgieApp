import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/bill_reminder.dart';
import 'package:budgie/models/favourite.dart';
import 'package:budgie/models/recurring_expense.dart';
import 'package:budgie/models/spending_calendar.dart';

void main() {
  group('Favourite', () {
    test('label is the note, or the category without one', () {
      expect(
        const Favourite(amount: 120, category: 'Transport', note: 'Bus').label,
        'Bus',
      );
      expect(
        const Favourite(amount: 120, category: 'Transport').label,
        'Transport',
      );
    });

    test('becomes an expense on the given date', () {
      final e = const Favourite(
        amount: 120,
        category: 'Transport',
        note: 'Bus',
        accountId: 4,
      ).toExpense(DateTime(2026, 5, 3, 8), accountId: 4);
      expect(e.amount, 120);
      expect(e.category, 'Transport');
      expect(e.note, 'Bus');
      expect(e.date, DateTime(2026, 5, 3, 8));
      expect(e.accountId, 4);
    });

    test('survives saving', () {
      final f = Favourite.fromMap(
        const Favourite(
          id: 2,
          amount: 50,
          category: 'Food',
          note: 'Tea',
        ).toMap(),
      );
      expect(f.id, 2);
      expect(f.label, 'Tea');
      expect(f.accountId, isNull);
    });
  });

  group('calendar helpers', () {
    test('weeks start on Monday', () {
      expect(leadingBlankDays(DateTime(2026, 6)), 0); // Monday 1 June
      expect(leadingBlankDays(DateTime(2026, 11)), 6); // Sunday 1 November
      expect(leadingBlankDays(DateTime(2026, 5)), 4); // Friday 1 May
    });

    test('shade grows with spending and stays between 0 and 1', () {
      expect(heatLevel(0, 100), 0);
      expect(heatLevel(50, 100), 0.5);
      expect(heatLevel(100, 100), 1);
      expect(heatLevel(10, 0), 0);
    });

    test('compact amounts fit a day cell', () {
      expect(compactAmount(850), '850');
      expect(compactAmount(999.6), '1000');
      expect(compactAmount(1250), '1.3k');
      expect(compactAmount(2000), '2k');
      expect(compactAmount(12500), '13k');
      expect(compactAmount(1250000), '1.3M');
    });
  });

  group('recurring income', () {
    RecurringExpense salary() => RecurringExpense(
      amount: 150000,
      category: 'Salary',
      frequency: RecurringFrequency.monthly,
      startDate: DateTime(2026, 7, 25),
      nextDue: DateTime(2026, 7, 25),
      isIncome: true,
    );

    test('kind survives saving, and old rows are expenses', () {
      expect(RecurringExpense.fromMap(salary().toMap()).isIncome, isTrue);
      final old = salary().toMap()..remove('kind');
      expect(RecurringExpense.fromMap(old).isIncome, isFalse);
      expect(salary().copyWith(active: false).isIncome, isTrue);
    });

    test('income gets no bill reminders', () {
      final reminders = planBillReminders(
        recurring: [salary()],
        now: DateTime(2026, 7, 1),
        daysBefore: 1,
        currency: 'Rs.',
      );
      expect(reminders, isEmpty);
    });
  });
}
