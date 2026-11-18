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

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;
  String _digits = '';
  int _attempts = 0;
  late AnimationController _shake;
  late Animation<double> _shakeAnim;
  String? _storedHash;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(_shake);
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
      setState(() {
        _attempts++;
        _digits = '';
      });
      _shake.forward(from: 0);
    }
  }

  Future<void> _forgotPin() async {
    final email = await db.getSetting('google_account', '');
    if (email.isNotEmpty) {
      final restored = await BackupService.instance.restore();
      if (!mounted) return;
      if (restored) {
        await BackupService.instance.restoreData();
      } else {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Could not restore backup'),
            content: const Text('Wipe data anyway?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Wipe')),
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
      if (changed == true && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Forgot PIN'),
          content: const Text('This will delete all your data. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete & Reset')),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_outline_rounded,
                size: 48, color: colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Enter PIN',
                style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 36),
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0),
                child: child,
              ),
              child: _dots(colorScheme),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 24,
              child: _attempts > 0
                  ? Text('Incorrect PIN',
                      style: TextStyle(
                          color: colorScheme.error, fontSize: 13))
                  : null,
            ),
            const Spacer(),
            _numpad(colorScheme),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: _attempts >= 5
                  ? TextButton(
                      onPressed: _forgotPin,
                      child: Text('Forgot PIN?',
                          style: TextStyle(color: colorScheme.error)),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _dots(ColorScheme cs) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _digits.length ? cs.primary : cs.surfaceContainerHighest,
              border: Border.all(
                color: i < _digits.length ? cs.primary : cs.outline,
                width: 1.5,
              ),
            ),
          ),
        ),
      );

  Widget _numpad(ColorScheme cs) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows
          .map((row) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) => _numKey(k, cs)).toList(),
              ))
          .toList(),
    );
  }

  Widget _numKey(String k, ColorScheme cs) {
    if (k.isEmpty) return const SizedBox(width: 88, height: 72);
    final isBackspace = k == '⌫';
    return SizedBox(
      width: 88,
      height: 72,
      child: TextButton(
        onPressed: isBackspace ? _onBackspace : () => _onDigit(k),
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          foregroundColor: isBackspace ? cs.onSurfaceVariant : cs.onSurface,
        ),
        child: isBackspace
            ? Icon(Icons.backspace_outlined, size: 22, color: cs.onSurfaceVariant)
            : Text(k,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w400)),
      ),
    );
  }
}
