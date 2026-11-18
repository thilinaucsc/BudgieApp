import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/recurring_expense.dart';

RecurringExpense _recurring(
  RecurringFrequency frequency,
  DateTime start, {
  DateTime? nextDue,
  bool active = true,
}) =>
    RecurringExpense(
      amount: 100,
      category: 'Bills',
      frequency: frequency,
      startDate: start,
      nextDue: nextDue ?? start,
      active: active,
    );

void main() {
  group('occurrenceAfter', () {
    test('weekly adds seven days across a month end', () {
      final r = _recurring(RecurringFrequency.weekly, DateTime(2026, 1, 28));
      expect(r.occurrenceAfter(DateTime(2026, 1, 28)), DateTime(2026, 2, 4));
    });

    test('monthly on the 31st caps at month end then returns to the 31st', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 1, 31));
      final feb = r.occurrenceAfter(DateTime(2026, 1, 31));
      expect(feb, DateTime(2026, 2, 28));
      final mar = r.occurrenceAfter(feb);
      expect(mar, DateTime(2026, 3, 31));
      expect(r.occurrenceAfter(mar), DateTime(2026, 4, 30));
    });

    test('monthly uses 29 February in a leap year', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2028, 1, 30));
      expect(r.occurrenceAfter(DateTime(2028, 1, 30)), DateTime(2028, 2, 29));
    });

    test('monthly rolls over the year', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 12, 15));
      expect(r.occurrenceAfter(DateTime(2026, 12, 15)), DateTime(2027, 1, 15));
    });

    test('yearly from 29 February caps then returns in the next leap year', () {
      final r = _recurring(RecurringFrequency.yearly, DateTime(2028, 2, 29));
      expect(r.occurrenceAfter(DateTime(2028, 2, 29)), DateTime(2029, 2, 28));
      expect(r.occurrenceAfter(DateTime(2031, 2, 28)), DateTime(2032, 2, 29));
    });
  });

  group('dueDates', () {
    test('is empty before the first payment', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 6, 10));
      expect(r.dueDates(DateTime(2026, 6, 9, 23, 59)), isEmpty);
    });

    test('includes a payment due today', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 6, 10));
      expect(r.dueDates(DateTime(2026, 6, 10, 0, 1)), [DateTime(2026, 6, 10)]);
    });

    test('catches up on every missed payment, oldest first', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 1, 31));
      expect(r.dueDates(DateTime(2026, 4, 1)), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      ]);
    });

    test('is empty while paused', () {
      final r = _recurring(RecurringFrequency.weekly, DateTime(2026, 1, 1),
          active: false);
      expect(r.dueDates(DateTime(2026, 6, 1)), isEmpty);
    });
  });

  group('upcomingDue', () {
    test('skips occurrences missed while paused', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 1, 15),
          active: false);
      expect(r.upcomingDue(DateTime(2026, 5, 20)), DateTime(2026, 6, 15));
    });

    test('keeps an occurrence that falls today', () {
      final r = _recurring(RecurringFrequency.monthly, DateTime(2026, 1, 15));
      expect(r.upcomingDue(DateTime(2026, 5, 15, 18)), DateTime(2026, 5, 15));
    });
  });

  test('toMap/fromMap round-trip preserves fields', () {
    final r = RecurringExpense(
      id: 3,
      amount: 2500.5,
      category: 'Bills',
      note: 'Internet',
      frequency: RecurringFrequency.yearly,
      startDate: DateTime(2026, 1, 31),
      nextDue: DateTime(2026, 3, 31),
      active: false,
    );
    final back = RecurringExpense.fromMap(r.toMap());
    expect(back.id, 3);
    expect(back.amount, 2500.5);
    expect(back.note, 'Internet');
    expect(back.frequency, RecurringFrequency.yearly);
    expect(back.startDate, DateTime(2026, 1, 31));
    expect(back.nextDue, DateTime(2026, 3, 31));
    expect(back.active, isFalse);
  });

  test('unknown frequency falls back to monthly', () {
    expect(RecurringFrequency.fromName('daily'), RecurringFrequency.monthly);
  });
}
