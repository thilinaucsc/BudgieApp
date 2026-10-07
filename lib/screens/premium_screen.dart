import 'package:flutter/material.dart';
import '../services/premium_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loading = false;

  Future<void> _buy() async {
    setState(() => _loading = true);
    final ok = await PremiumService.instance.buy();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to the store. Try again later.')),
      );
    }
    // Purchase result arrives via PremiumService stream; the listener in
    // add_expense_screen will re-check isPremium when this screen pops.
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    await PremiumService.instance.restore();
    if (!mounted) return;
    setState(() => _loading = false);

    final premium = await PremiumService.instance.isPremium();
    if (!mounted) return;
    if (premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase restored!')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchase found.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(Icons.star_rounded, size: 72, color: cs.primary),
            const SizedBox(height: 24),
            Text(
              'Budgie Premium',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'One-time purchase — yours forever.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 36),
            _featureTile(
              Icons.camera_alt_outlined,
              'Scan bills with your camera',
              'Point your camera at any receipt and the app fills in the amount, date, and category automatically.',
            ),
            const Spacer(),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton(
                onPressed: _buy,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: const Text('Unlock Premium'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _restore,
                child: const Text('Restore purchase'),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String title, String subtitle) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      );
}
