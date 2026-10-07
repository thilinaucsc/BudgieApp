import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/backup_service.dart';
import 'set_pin_screen.dart';

class PinScreen extends StatefulWidget {
  final String? storedHash; // injected for testing; null = load from DB
  const PinScreen({super.key, this.storedHash});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;
  String _digits = '';
  int _attempts = 0;
  late AnimationController _shake;
  late Animation<double> _shakeAnim;
  String? _storedHash;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _shakeAnim = Tween(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shake);
    _storedHash = widget.storedHash;
    if (_storedHash == null) _loadHash();
  }

  Future<void> _loadHash() async {
    final h = await db.getSetting('pin_hash', '');
    if (mounted) setState(() => _storedHash = h);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() => _digits += d);
    if (_digits.length == 4) _onComplete();
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _onComplete() async {
    final hash = _storedHash ?? await db.getSetting('pin_hash', '');
    if (hashPin(_digits) == hash) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() { _attempts++; _digits = ''; });
      _shake.forward(from: 0);
    }
  }

  Future<void> _forgotPin() async {
    final email = await db.getSetting('google_account', '');
    if (email.isNotEmpty) {
      final restored = await BackupService.instance.restore();
      if (!mounted) return;
      if (restored) {
        await db.wipeAll();
        await BackupService.instance.restoreData();
      } else {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Could not restore backup'),
            content: const Text('Wipe data anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Wipe')),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
        await db.wipeAll();
      }
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
      if (changed == true && mounted) Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Forgot PIN'),
          content: const Text('This will delete all your data. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete & Reset')),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await db.wipeAll();
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text('Enter PIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value * (_attempts.isEven ? 1 : -1), 0),
                child: child,
              ),
              child: _dots(),
            ),
            const SizedBox(height: 16),
            if (_attempts > 0)
              Text('Incorrect PIN', style: TextStyle(color: Colors.red.shade600)),
            const SizedBox(height: 32),
            _numpad(),
            const SizedBox(height: 24),
            if (_attempts >= 5)
              TextButton(
                onPressed: _forgotPin,
                child: const Text('Forgot PIN?', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _digits.length ? Colors.teal : Colors.grey.shade300,
          ),
        )),
      );

  Widget _numpad() {
    final keys = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return Wrap(
      alignment: WrapAlignment.center,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox(width: 80, height: 70);
        return SizedBox(
          width: 80, height: 70,
          child: TextButton(
            onPressed: k == '⌫' ? _onBackspace : () => _onDigit(k),
            child: Text(k, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }
}
