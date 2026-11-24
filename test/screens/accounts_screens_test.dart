import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budgie/db/database_helper.dart';
import 'package:budgie/models/account.dart';
import 'package:budgie/models/household_item.dart';
import 'package:budgie/screens/accounts_screen.dart';
import 'package:budgie/screens/add_expense_screen.dart';
import 'package:budgie/screens/household_screen.dart';
import 'package:budgie/screens/pin_screen.dart';
import 'package:budgie/screens/transfer_screen.dart';

final _db = DatabaseHelper.instance;

// The no-isolate factory answers on microtasks, so pumping lets queries finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('budgie_accounts_screens_').path,
    );
  });

  setUp(() async {
    await _db.wipeAll();
    await _db.database;
  });

  tearDownAll(() async {
    await _db.wipeAll();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
    await _settle(tester);
  }

  Future<int> account(String name, double opening) => _db.insertAccount(
    Account(name: name, type: AccountType.bank, openingBalance: opening),
  );

  testWidgets('accounts list shows each balance and the total', (tester) async {
    await tester.runAsync(() async {
      await account('Bank', 1000);
      await account('Visa', -250);
    });

    await pumpScreen(tester, const AccountsScreen());

    expect(find.text('Rs. 1,000.00'), findsOneWidget);
    expect(find.text('-Rs. 250.00'), findsOneWidget);
    expect(find.text('Rs. 750.00'), findsOneWidget);
    expect(find.byTooltip('Move money'), findsOneWidget);
  });

  testWidgets('a new account is saved from the dialog', (tester) async {
    await pumpScreen(tester, const AccountsScreen());
    expect(find.text('No accounts yet'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Cash');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Money in it now'),
      '500',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text('Cash'), findsWidgets);
    expect(find.text('Rs. 500.00'), findsWidgets);
  });

  testWidgets('moving money starts with two different accounts', (
    tester,
  ) async {
    late List<Account> accounts;
    await tester.runAsync(() async {
      await account('Bank', 1000);
      await account('Cash', 0);
      accounts = await _db.getAccounts();
    });

    await pumpScreen(
      tester,
      TransferScreen(
        accounts: accounts,
        currency: 'Rs.',
        fromAccount: accounts[1].id,
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Move money'));
    await tester.pump();

    expect(find.text('Choose two different accounts'), findsNothing);
    expect(find.text('Enter an amount greater than 0'), findsNothing);
  });

  testWidgets('expense form asks which account once one exists', (
    tester,
  ) async {
    final note = find.widgetWithText(TextFormField, 'Note (optional)');
    await pumpScreen(tester, const AddExpenseScreen());
    await tester.scrollUntilVisible(
      note,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paid from'), findsNothing);

    await tester.runAsync(() => account('Bank', 0));
    // A new key makes the form load again instead of reusing its state.
    await pumpScreen(tester, AddExpenseScreen(key: UniqueKey()));
    await tester.scrollUntilVisible(
      note,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paid from'), findsOneWidget);
  });

  testWidgets('buy list offers sharing and marking as bought', (tester) async {
    await tester.runAsync(
      () => _db.insertItem(
        HouseholdItem(name: 'Rice', quantity: 0, minQuantity: 2, unit: 'kg'),
      ),
    );

    await pumpScreen(tester, const HouseholdScreen());
    await tester.tap(find.text('Buy List'));
    await tester.pumpAndSettle();

    expect(find.text('Share list'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark Rice as bought'));
    await tester.pumpAndSettle();
    expect(find.text('Bought Rice'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Add to stock'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('Added 4 kg to Rice'), findsOneWidget);
  });

  testWidgets('the auto-lock screen cannot be skipped with Back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PinScreen(
                    storedHash: 'abc',
                    biometricEnabled: false,
                    relock: true,
                  ),
                ),
              ),
              child: const Text('Open lock'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open lock'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Enter PIN'), findsOneWidget);
  });

  testWidgets('new screens render in dark mode', (tester) async {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.dark,
      ),
    );
    await tester.runAsync(() => account('Bank', 10));
    await pumpScreen(tester, const AccountsScreen(), theme: dark);
    expect(tester.takeException(), isNull);
  });
}
