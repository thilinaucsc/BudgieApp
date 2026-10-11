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
          _googleEmail = googleAccount.isEmpty ? null : googleAccount;
        }
      });
    } catch (_) {
      // DB unavailable (e.g. in unit tests); initial values remain
    }
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
    if (result == true) {
      await _load();
    }
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
        const SnackBar(content: Text('Restore failed — no backup found')),
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
          const SnackBar(content: Text('Restored from cloud backup')),
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
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly budget from $monthName',
                helperText:
                    'This budget also applies to later months until you change it.',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final value = double.tryParse(t);
                if (value == null || value <= 0) return 'Enter a number greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency symbol',
                hintText: r'Rs., $, €',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a currency symbol' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save settings'),
            ),
            const Divider(height: 40),

            // ── PIN ──────────────────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: Text(_pinSet ? 'Change PIN' : 'Set PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setPinTapped,
            ),

            const Divider(height: 8),

            // ── Google Account ───────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined),
              title: Text(_googleEmail != null
                  ? 'Unlink Google ($_googleEmail)'
                  : 'Link Google Account'),
              subtitle: _googleEmail == null
                  ? const Text('Enable cloud backup & PIN recovery')
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _googleTapped,
            ),
            if (_googleEmail != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Back up now'),
                onTap: _backupNow,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore_outlined),
                title: const Text('Restore from cloud'),
                onTap: _restoreFromCloud,
              ),
            ],

            const Divider(height: 8),

            // ── Premium ──────────────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline_rounded),
              title: const Text('Upgrade to Premium'),
              subtitle: const Text('Unlock bill photo scanning'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore_page_outlined),
              title: const Text('Restore purchase'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await PremiumService.instance.restore();
                if (!mounted) return;
                final premium = await PremiumService.instance.isPremium();
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text(premium
                      ? 'Premium restored!'
                      : 'No previous purchase found.'),
                ));
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
