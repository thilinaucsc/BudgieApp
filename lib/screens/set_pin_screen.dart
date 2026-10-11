import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final db = DatabaseHelper.instance;
  int _step = 0; // 0 = enter new PIN, 1 = confirm
  String _first = '';
  String _digits = '';

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
    if (_step == 0) {
      setState(() {
        _first = _digits;
        _step = 1;
        _digits = '';
      });
    } else {
      if (_digits == _first) {
        await db.setSetting('pin_hash', hashPin(_digits));
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PINs do not match')),
          );
          setState(() { _step = 0; _first = ''; _digits = ''; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            _step == 0 ? 'Enter new PIN' : 'Confirm PIN',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _dots(cs),
          const SizedBox(height: 32),
          _numpad(),
        ],
      ),
    );
  }

  Widget _dots(ColorScheme cs) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _digits.length ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(
              color: i < _digits.length ? cs.primary : cs.outline,
              width: 1.5,
            ),
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
