import 'package:flutter/material.dart';

enum AccountType {
  cash('Cash', Icons.payments_outlined),
  bank('Bank', Icons.account_balance_outlined),
  card('Card', Icons.credit_card),
  other('Other', Icons.account_balance_wallet_outlined);

  const AccountType(this.label, this.icon);
  final String label;
  final IconData icon;

  static AccountType fromName(String name) => values.firstWhere(
        (t) => t.name == name,
        orElse: () => AccountType.other,
      );
}

class Account {
  final int? id;
  final String name;
  final AccountType type;

  /// Money in the account before anything was recorded in Budgie.
  final double openingBalance;

  /// Opening balance plus income and transfers in, minus expenses and
  /// transfers out. Worked out by the database.
  final double balance;

  Account({
    this.id,
    required this.name,
    required this.type,
    this.openingBalance = 0,
    double? balance,
  }) : balance = balance ?? openingBalance;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'opening_balance': openingBalance,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: AccountType.fromName(m['type'] as String),
        openingBalance: (m['opening_balance'] as num).toDouble(),
        balance: (m['balance'] as num?)?.toDouble(),
      );
}

class AccountTransfer {
  final int? id;
  final int fromAccount;
  final int toAccount;
  final double amount;
  final DateTime date;
  final String note;

  AccountTransfer({
    this.id,
    required this.fromAccount,
    required this.toAccount,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'from_account': fromAccount,
        'to_account': toAccount,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };
}

enum ActivityKind { expense, income, transferIn, transferOut }

/// One line in an account's history. [amount] is positive for money coming
/// in and negative for money going out.
class AccountActivity {
  final ActivityKind kind;
  final int id;
  final DateTime date;
  final String title;
  final String note;
  final double amount;

  const AccountActivity({
    required this.kind,
    required this.id,
    required this.date,
    required this.title,
    required this.note,
    required this.amount,
  });

  bool get isTransfer =>
      kind == ActivityKind.transferIn || kind == ActivityKind.transferOut;
}

/// Why [name] can't be used for an account, or null when it is fine.
String? accountNameError(String name, List<Account> existing, {int? id}) {
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return 'Enter a name';
  final taken =
      existing.any((a) => a.id != id && a.name.toLowerCase() == wanted);
  return taken ? 'You already have an account with this name' : null;
}
