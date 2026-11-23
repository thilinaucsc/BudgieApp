import 'package:intl/intl.dart';
import 'recurring_expense.dart';

class PlannedReminder {
  final int id;
  final DateTime when;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  String get signature => '$id|${when.toIso8601String()}|$title|$body';
}

const int billReminderHour = 9;
const int firstBillReminderId = 100;

// iOS keeps at most 64 pending notifications per app.
const int maxBillReminders = 50;
const int _occurrencesPerBill = 4;

String _dueLabel(int daysBefore) => switch (daysBefore) {
      0 => 'due today',
      1 => 'due tomorrow',
      _ => 'due in $daysBefore days',
    };

/// The soonest upcoming reminders for active recurring expenses.
List<PlannedReminder> planBillReminders({
  required List<RecurringExpense> recurring,
  required DateTime now,
  required int daysBefore,
  required String currency,
}) {
  final money = NumberFormat('#,##0.00');
  final planned = <({DateTime when, String title, String body})>[];
  for (final bill in recurring.where((r) => r.active)) {
    var due = bill.upcomingDue(now);
    for (var i = 0; i < _occurrencesPerBill; i++) {
      final when = DateTime(
          due.year, due.month, due.day - daysBefore, billReminderHour);
      if (when.isAfter(now)) {
        planned.add((
          when: when,
          title: bill.note.isNotEmpty ? bill.note : bill.category,
          body: '$currency ${money.format(bill.amount)} ${_dueLabel(daysBefore)}',
        ));
      }
      due = bill.occurrenceAfter(due);
    }
  }
  planned.sort((a, b) => a.when.compareTo(b.when));
  return [
    for (final (i, p) in planned.take(maxBillReminders).indexed)
      PlannedReminder(
        id: firstBillReminderId + i,
        when: p.when,
        title: p.title,
        body: p.body,
      ),
  ];
}
