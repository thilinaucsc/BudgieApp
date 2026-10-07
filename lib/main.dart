import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/household_screen.dart';
import 'screens/pin_screen.dart';
import 'services/backup_service.dart';

void main() => runApp(const ExpenseApp());

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budgie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const _StartupRouter(),
      routes: {'/home': (_) => const RootScreen()},
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final pin = await DatabaseHelper.instance.getSetting('pin_hash', '');
    if (!mounted) return;
    setState(() => _screen = pin.isEmpty ? const RootScreen() : const PinScreen());
  }

  @override
  Widget build(BuildContext context) => _screen ??
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int _tab = 0;
  int _lowCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLowCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      BackupService.instance.backup();
    }
  }

  Future<void> _refreshLowCount() async {
    final count = await DatabaseHelper.instance.lowStockCount();
    if (mounted) setState(() => _lowCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), HouseholdScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _refreshLowCount();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: _lowCount > 0
                ? Badge(label: Text('$_lowCount'), child: const Icon(Icons.home_outlined))
                : const Icon(Icons.home_outlined),
            selectedIcon: _lowCount > 0
                ? Badge(label: Text('$_lowCount'), child: const Icon(Icons.home))
                : const Icon(Icons.home),
            label: 'Household',
          ),
        ],
      ),
    );
  }
}
