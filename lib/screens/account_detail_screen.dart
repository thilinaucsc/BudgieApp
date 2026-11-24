import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/account.dart';
import 'accounts_screen.dart';
import 'transfer_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final int accountId;
  final String currency;
  const AccountDetailScreen({
    super.key,
    required this.accountId,
    required this.currency,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<Account> accounts = [];
  Account? account;
  List<AccountActivity> activity = [];

  String _amount(double v, {bool sign = false}) =>
      '${v < 0 ? '-' : (sign ? '+' : '')}${widget.currency} '
      '${money.format(v.abs())}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await db.getAccounts();
    final a = await db.accountActivity(widget.accountId);
    if (!mounted) return;
    setState(() {
      accounts = all;
      account = all.where((x) => x.id == widget.accountId).firstOrNull;
      activity = a;
    });
  }

  Future<void> _edit() async {
    final updated = await showDialog<Account>(
      context: context,
      builder: (_) => AccountDialog(
          account: account, existing: accounts, currency: widget.currency),
    );
    if (updated == null) return;
    await db.updateAccount(updated);
    _load();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${account!.name}?'),
        content: const Text(
            'Its transfers will be deleted. Expenses and income stay in '
            'Budgie but no longer belong to an account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.deleteAccount(widget.accountId);
    navigator.pop(true);
  }

  Future<void> _transfer() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          accounts: accounts,
          currency: widget.currency,
          fromAccount: widget.accountId,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = account;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(current?.name ?? ''),
        actions: [
          if (accounts.length >= 2)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Move money',
              onPressed: _transfer,
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit account',
            onPressed: current == null ? null : _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete account',
            onPressed: current == null ? null : _delete,
          ),
        ],
      ),
      body: current == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Balance',
                            style: TextStyle(color: cs.outline, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          _amount(current.balance),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: current.balance < 0 ? cs.error : null,
                          ),
                        ),
                        Text(
                          'Started with ${_amount(current.openingBalance)}',
                          style: TextStyle(color: cs.outline, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if (activity.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing recorded in this account yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.outline),
                    ),
                  )
                else
                  for (final item in activity) _activity(item, cs),
              ],
            ),
    );
  }

  Widget _activity(AccountActivity item, ColorScheme cs) {
    final icon = switch (item.kind) {
      ActivityKind.expense => Icons.arrow_upward,
      ActivityKind.income => Icons.arrow_downward,
      ActivityKind.transferIn || ActivityKind.transferOut =>
        Icons.swap_horiz_rounded,
    };
    final detail = [
      DateFormat('d MMM yyyy').format(item.date),
      if (item.note.isNotEmpty) item.note,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: item.amount < 0 ? cs.error : cs.primary),
        title: Text(item.title),
        subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _amount(item.amount, sign: true),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: item.amount < 0 ? cs.error : cs.primary,
              ),
            ),
            if (item.isTransfer)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Delete transfer',
                onPressed: () async {
                  await db.deleteTransfer(item.id);
                  _load();
                },
              ),
          ],
        ),
      ),
    );
  }
}
