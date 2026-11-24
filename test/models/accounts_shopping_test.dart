import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/account.dart';
import 'package:budgie/models/household_item.dart';
import 'package:budgie/models/shopping.dart';
import 'package:budgie/services/app_lock.dart';

void main() {
  group('accountNameError', () {
    final existing = [
      Account(id: 1, name: 'Cash', type: AccountType.cash),
      Account(id: 2, name: 'BOC', type: AccountType.bank),
    ];

    test('names must be filled in and new, ignoring capitals', () {
      expect(accountNameError(' ', existing), isNotNull);
      expect(accountNameError('cash', existing), isNotNull);
      expect(accountNameError('Visa', existing), isNull);
    });

    test('an account can keep its own name', () {
      expect(accountNameError('Cash', existing, id: 1), isNull);
      expect(accountNameError('Cash', existing, id: 2), isNotNull);
    });

    test('type survives saving and unknown types fall back to other', () {
      final saved = Account.fromMap(
          Account(id: 3, name: 'Visa', type: AccountType.card).toMap());
      expect(saved.type, AccountType.card);
      expect(saved.balance, 0);
      expect(AccountType.fromName('crypto'), AccountType.other);
    });
  });

  group('AppLock', () {
    final left = DateTime(2026, 5, 1, 10);

    test('locks once the chosen time has passed', () {
      expect(
          AppLock.shouldLock(
              leftAt: left,
              now: left.add(const Duration(minutes: 5)),
              minutes: 5),
          isTrue);
      expect(
          AppLock.shouldLock(
              leftAt: left,
              now: left.add(const Duration(minutes: 4, seconds: 59)),
              minutes: 5),
          isFalse);
    });

    test('never locks when off or when the app never left', () {
      final later = left.add(const Duration(hours: 5));
      expect(AppLock.shouldLock(leftAt: left, now: later, minutes: 0), isFalse);
      expect(AppLock.shouldLock(leftAt: null, now: later, minutes: 1), isFalse);
    });

    test('unknown saved values turn auto-lock off', () {
      expect(AppLock.parse('5'), 5);
      expect(AppLock.parse('7'), 0);
      expect(AppLock.parse('soon'), 0);
      expect(AppLock.label(0), 'Off');
      expect(AppLock.label(1), 'After 1 minute');
      expect(AppLock.label(15), 'After 15 minutes');
    });
  });

  group('shopping', () {
    HouseholdItem item(double qty, double min, [String unit = 'kg']) =>
        HouseholdItem(
            name: 'Rice', quantity: qty, minQuantity: min, unit: unit);

    test('suggests enough to reach twice the minimum', () {
      expect(suggestedPurchase(item(1, 2)), 3);
      expect(suggestedPurchase(item(0, 1.5)), 3);
      expect(suggestedPurchase(item(0.25, 0.5)), 0.8);
    });

    test('always suggests at least one', () {
      expect(suggestedPurchase(item(5, 2)), 1);
      expect(suggestedPurchase(item(0, 0)), 1);
    });

    test('the shared list names each item and amount', () {
      expect(
        shoppingListText([item(1, 2), item(0, 3, 'pcs')]),
        'Shopping list\n• Rice: 3 kg\n• Rice: 6 pcs',
      );
    });

    test('quantities drop needless decimals', () {
      expect(formatQuantity(2), '2');
      expect(formatQuantity(1.5), '1.5');
    });
  });
}
