import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/household_screen.dart';
import 'screens/pin_screen.dart';
import 'services/backup_service.dart';
import 'services/premium_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PremiumService.instance.initialize();
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budgie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 65,
          elevation: 0,
          indicatorShape: StadiumBorder(),
        ),
      ),
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
