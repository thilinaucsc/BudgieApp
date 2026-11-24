import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/account.dart';
import 'account_detail_screen.dart';
import 'transfer_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<Account> accounts = [];
  String currency = 'Rs.';
  bool loading = true;

  String _amount(double v) =>
      '${v < 0 ? '-' : ''}$currency ${money.format(v.abs())}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await db.getAccounts();
    final c = await db.getSetting('currency', 'Rs.');
    if (!mounted) return;
    setState(() {
      accounts = a;
      currency = c;
      loading = false;
    });
  }

  Future<void> _add() async {
    final account = await showDialog<Account>(
      context: context,
      builder: (_) =>
          AccountDialog(existing: accounts, currency: currency),
    );
    if (account == null) return;
    await db.insertAccount(account);
    _load();
  }

  Future<void> _transfer() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(accounts: accounts, currency: currency),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _open(Account account) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AccountDetailScreen(accountId: account.id!, currency: currency),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = accounts.fold<double>(0, (s, a) => s + a.balance);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          if (accounts.length >= 2)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Move money',
              onPressed: _transfer,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Add account',
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? _emptyState(cs)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total in all accounts',
                                style: TextStyle(
                                    color: cs.outline, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              _amount(total),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: total < 0 ? cs.error : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final a in accounts)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          onTap: () => _open(a),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(a.type.icon, color: cs.primary),
                          ),
                          title: Text(a.name),
                          subtitle: Text(a.type.label),
                          trailing: Text(
                            _amount(a.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: a.balance < 0 ? cs.error : cs.primary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'New expenses and income use the account you picked '
                      'last. Older entries without an account are not '
                      'counted here.',
                      style: TextStyle(color: cs.outline, fontSize: 12),
                    ),
                  ],
                ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'No accounts yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Cash, Bank or Card to see what is left in each one',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Creates or edits an account. Returns the account to save.
class AccountDialog extends StatefulWidget {
  final Account? account;
  final List<Account> existing;
  final String currency;

  const AccountDialog({
    super.key,
    this.account,
    required this.existing,
    required this.currency,
  });

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late AccountType _type;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _opening = TextEditingController(
        text: a == null ? '' : a.openingBalance.toString());
    _type = a?.type ?? AccountType.cash;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final opening = _opening.text.trim();
    Navigator.pop(
      context,
      Account(
        id: widget.account?.id,
        name: _name.text.trim(),
        type: _type,
        openingBalance: opening.isEmpty ? 0 : double.parse(opening),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'New account' : 'Edit account'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in AccountType.values)
                      ChoiceChip(
                        avatar: Icon(t.icon, size: 18),
                        showCheckmark: false,
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() {
                          // Suggest the type as a name until one is typed.
                          if (_name.text.trim().isEmpty ||
                              AccountType.values
                                  .any((x) => x.label == _name.text.trim())) {
                            _name.text = t.label;
                          }
                          _type = t;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Cash, BOC savings, Visa...',
                  ),
                  validator: (v) => accountNameError(
                      v ?? '', widget.existing,
                      id: widget.account?.id),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Money in it now',
                    prefixText: '${widget.currency} ',
                    helperText: 'Use a minus for money owed on a card',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return double.tryParse(t) == null
                        ? 'Enter a number'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
