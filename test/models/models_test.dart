import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/models/expense_category.dart';
import 'package:budgie/models/household_item.dart';
import 'package:budgie/models/splitter_expense.dart';
import 'package:budgie/models/splitter_participant.dart';
import 'package:budgie/models/splitter_trip.dart';

void main() {
  group('Expense', () {
    test('toMap/fromMap round-trip preserves fields', () {
      final e = Expense(
        id: 7,
        amount: 1250.5,
        category: 'Groceries',
        date: DateTime(2026, 10, 7, 14, 30),
        note: 'Cargills',
      );
      final back = Expense.fromMap(e.toMap());
      expect(back.id, 7);
      expect(back.amount, 1250.5);
      expect(back.category, 'Groceries');
      expect(back.date, DateTime(2026, 10, 7, 14, 30));
      expect(back.note, 'Cargills');
    });

    test('fromMap accepts integer amount and missing note', () {
      final e = Expense.fromMap({
        'id': 1,
        'amount': 500,
        'category': 'Food',
        'date': '2026-01-01T00:00:00.000',
        'note': null,
      });
      expect(e.amount, 500.0);
      expect(e.note, '');
    });

    test('note defaults to empty string', () {
      final e = Expense(amount: 1, category: 'Food', date: DateTime(2026));
      expect(e.note, '');
      expect(e.toMap()['id'], isNull);
    });
  });

  group('categoryByName', () {
    test('returns matching category', () {
      expect(categoryByName('Transport').name, 'Transport');
    });

    test('falls back to Other for unknown names', () {
      expect(categoryByName('Nope').name, 'Other');
      expect(categoryByName('').name, 'Other');
    });

    test('category names are unique', () {
      final names = categories.map((c) => c.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('HouseholdItem', () {
    HouseholdItem item(double qty, double min) =>
        HouseholdItem(name: 'Rice', quantity: qty, minQuantity: min, unit: 'kg');

    test('isLow is true at or below minimum', () {
      expect(item(1, 2).isLow, isTrue);
      expect(item(2, 2).isLow, isTrue);
      expect(item(3, 2).isLow, isFalse);
    });

    test('toMap uses snake_case and round-trips', () {
      final i = HouseholdItem(
          id: 3, name: 'Rice', quantity: 5, minQuantity: 1.5, unit: 'kg');
      final map = i.toMap();
      expect(map['min_quantity'], 1.5);
      final back = HouseholdItem.fromMap(map);
      expect(back.id, 3);
      expect(back.name, 'Rice');
      expect(back.quantity, 5.0);
      expect(back.minQuantity, 1.5);
      expect(back.unit, 'kg');
    });

    test('fromMap accepts integer quantities', () {
      final i = HouseholdItem.fromMap(
          {'id': null, 'name': 'Soap', 'quantity': 2, 'min_quantity': 1, 'unit': 'pcs'});
      expect(i.quantity, 2.0);
      expect(i.minQuantity, 1.0);
      expect(i.id, isNull);
    });
  });

  group('Splitter models', () {
    test('SplitterTrip round-trip', () {
      final t = SplitterTrip(id: 1, name: 'Ella', createdAt: DateTime(2026, 5, 1));
      final back = SplitterTrip.fromMap(t.toMap());
      expect(back.id, 1);
      expect(back.name, 'Ella');
      expect(back.createdAt, DateTime(2026, 5, 1));
    });

    test('SplitterParticipant round-trip', () {
      final p = SplitterParticipant(id: 2, tripId: 1, name: 'Bob');
      final back = SplitterParticipant.fromMap(p.toMap());
      expect(back.id, 2);
      expect(back.tripId, 1);
      expect(back.name, 'Bob');
    });

    test('SplitterExpense toMap emits only stored columns', () {
      final e = SplitterExpense(
        id: 4,
        tripId: 1,
        payerId: 2,
        amount: 99.99,
        note: 'Dinner',
        date: DateTime(2026, 5, 2),
        payerName: 'Bob',
        shareParticipantIds: [1, 2],
      );
      final map = e.toMap();
      expect(map.keys.toSet(),
          {'id', 'trip_id', 'payer_id', 'amount', 'note', 'date'});
      final back = SplitterExpense.fromMap(map);
      expect(back.amount, 99.99);
      expect(back.note, 'Dinner');
      expect(back.payerId, 2);
      expect(back.shareParticipantIds, isEmpty);
    });

    test('SplitterExpense fromMap tolerates null note', () {
      final e = SplitterExpense.fromMap({
        'id': 1,
        'trip_id': 1,
        'payer_id': 1,
        'amount': 10,
        'note': null,
        'date': '2026-05-02T00:00:00.000',
      });
      expect(e.note, '');
      expect(e.amount, 10.0);
    });
  });
}
