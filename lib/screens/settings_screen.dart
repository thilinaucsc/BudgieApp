import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../services/backup_service.dart';
import '../services/premium_service.dart';
import 'premium_screen.dart';
import 'set_pin_screen.dart';

class SettingsScreen extends StatefulWidget {
  final DateTime month;
  final bool? initialPinSet;
  final String? initialGoogleEmail;

  const SettingsScreen({
    super.key,
    required this.month,
    this.initialPinSet,
    this.initialGoogleEmail,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budget = TextEditingController();
  final _currency = TextEditingController();
  final db = DatabaseHelper.instance;

  bool _pinSet = false;
  String? _googleEmail;

  @override
  void initState() {
    super.initState();
    _pinSet = widget.initialPinSet ?? false;
    _googleEmail = widget.initialGoogleEmail;
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await db.getBudget(widget.month);
      final c = await db.getSetting('currency', 'Rs.');
      final pinHash = await db.getSetting('pin_hash', '');
      final googleAccount = await db.getSetting('google_account', '');
      if (!mounted) return;
      setState(() {
        _budget.text = b == null ? '' : b.toStringAsFixed(0);
        _currency.text = c;
        if (widget.initialPinSet == null) {
          _pinSet = pinHash.isNotEmpty;
        }
        if (widget.initialGoogleEmail == null) {
          _googleEmail =
              googleAccount.isEmpty ? null : googleAccount;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _budget.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final text = _budget.text.trim();
    if (text.isNotEmpty) {
      await db.setBudget(widget.month, double.parse(text));
    }
    await db.setSetting('currency', _currency.text.trim());
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _setPinTapped() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetPinScreen()),
    );
    if (result == true) await _load();
  }

  Future<void> _googleTapped() async {
    if (_googleEmail != null) {
      await BackupService.instance.signOut();
    } else {
      await BackupService.instance.signIn();
    }
    await _load();
  }

  Future<void> _backupNow() async {
    await BackupService.instance.backup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backed up to Google Drive')),
      );
    }
  }

  Future<void> _restoreFromCloud() async {
    final ok = await BackupService.instance.restore();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Restore failed — no backup found')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from cloud?'),
        content: const Text(
            'This will overwrite your local data with the cloud backup. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed == true) {
      await db.wipeAll();
      await BackupService.instance.restoreData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Restored from cloud backup')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(widget.month);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            _sectionCard(
              'Budget',
              [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextFormField(
                    controller: _budget,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly budget from $monthName',
                      helperText:
                          'Applies to later months until you change it.',
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final value = double.tryParse(t);
                      if (value == null || value <= 0) {
                        return 'Enter a number greater than 0';
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextFormField(
                    controller: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency symbol',
                      hintText: r'Rs., $, €',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter a currency symbol'
                        : null,
                  ),
                ),
              ],
            ),
            FilledButton(onPressed: _save, child: const Text('Save settings')),
            const SizedBox(height: 28),
            _sectionCard(
              'Security & Backup',
              [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(_pinSet ? 'Change PIN' : 'Set PIN'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _setPinTapped,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(_googleEmail != null
                      ? 'Unlink Google'
                      : 'Link Google Account'),
                  subtitle: _googleEmail != null
                      ? Text(_googleEmail!,
                          style: const TextStyle(fontSize: 12))
                      : const Text('Enable cloud backup & PIN recovery'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _googleTapped,
                ),
                if (_googleEmail != null) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Back up now'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _backupNow,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.restore_outlined),
                    title: const Text('Restore from cloud'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _restoreFromCloud,
                  ),
                ],
              ],
            ),
            _sectionCard(
              'Premium',
              [
                ListTile(
                  leading: Icon(Icons.star_outline_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Upgrade to Premium'),
                  subtitle: const Text('Unlock bill photo scanning'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PremiumScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: const Text('Restore purchase'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await PremiumService.instance.restore();
                    if (!mounted) return;
                    final premium =
                        await PremiumService.instance.isPremium();
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(
                      content: Text(premium
                          ? 'Premium restored!'
                          : 'No previous purchase found.'),
                    ));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
