# Bill Splitter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent bill-splitter third tab: create named trips, log who paid what, split equally among selected participants, view minimised settlements, share as text or image.

**Architecture:** Six tasks in dependency order — packages + DB + models first, then a pure settlement service (unit-tested in isolation), then three new screens, then navigation wiring. Each task compiles and is testable before the next begins.

**Tech Stack:** Flutter, sqflite (existing), share_plus (new), path_provider (new), dart:ui (built-in) for image capture.

**Spec:** `docs/superpowers/specs/2026-10-11-bill-splitter-design.md`

## Global Constraints

- DB version bumps exactly **2 → 3**; migration block must use `if (oldVersion < 3)`
- All UI colours via `Theme.of(context).colorScheme`; zero hardcoded colours
- Equal split only: `amount / shareParticipantIds.length`
- New packages: `share_plus: ^10.0.0`, `path_provider: ^2.1.0`
- Swipe-to-delete on every list with a confirm `AlertDialog` before committing
- `flutter analyze` must report zero issues after each task commit

## Review Focus

1. **Trip with no expenses** → `settle()` returns `[]`; Settlements tab shows "All even!" empty state — tested in Task 2, empty-state render verified in Task 5.
2. **All expenses paid by one person** → exactly n−1 settlements each pointing to that one creditor — tested in Task 2.
3. **Participant with zero net balance** (paid nothing, in no expense shares) → excluded from settlements list — tested in Task 2.
4. **Expense shared by only the payer** (everyone else unchecked) → payer's net is zero for that expense; no spurious settlement — tested in Task 2.
5. **Floating-point accumulation** → `settle()` rounds each per-share contribution to 4 decimal places before summing; final settlement amounts rounded to 2 dp — documented and enforced in Task 2.

---

### Task 1: Packages, DB schema, models, CRUD

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/db/database_helper.dart`
- Create: `lib/models/splitter_trip.dart`
- Create: `lib/models/splitter_participant.dart`
- Create: `lib/models/splitter_expense.dart`

**Interfaces:**
- Produces (models):
  - `SplitterTrip({int? id, required String name, required DateTime createdAt})` — `toMap()`, `SplitterTrip.fromMap(Map<String,dynamic>)`
  - `SplitterParticipant({int? id, required int tripId, required String name})` — `toMap()`, `fromMap`
  - `SplitterExpense({int? id, required int tripId, required int payerId, required double amount, required String note, required DateTime date, String payerName = '', List<int> shareParticipantIds = const []})` — `toMap()` emits only stored columns (`id`, `trip_id`, `payer_id`, `amount`, `note`, `date`); `fromMap` sets `payerName = ''` and `shareParticipantIds = []`
- Produces (DB methods on `DatabaseHelper`):
  - `Future<int> insertSplitterTrip(SplitterTrip trip)`
  - `Future<List<SplitterTrip>> getAllSplitterTrips()` — ORDER BY `created_at DESC`
  - `Future<void> deleteSplitterTrip(int id)` — cascade: delete shares → expenses → participants → trip
  - `Future<int> insertSplitterParticipant(SplitterParticipant p)`
  - `Future<List<SplitterParticipant>> participantsForTrip(int tripId)` — ORDER BY `id ASC`
  - `Future<int> insertSplitterExpense(SplitterExpense e)` — inserts expense row then inserts one `splitter_expense_shares` row per id in `e.shareParticipantIds`
  - `Future<List<SplitterExpense>> expensesForTrip(int tripId)` — query `splitter_expenses` joined to `splitter_participants` on `payer_id = participants.id` to get `payerName`; then for each expense load its share ids from `splitter_expense_shares`; ORDER BY `date DESC, id DESC`
  - `Future<void> deleteSplitterExpense(int id)` — delete shares first, then expense row
  - `Future<double> splitterTripTotal(int tripId)` — `SELECT COALESCE(SUM(amount),0.0)`

- [ ] Add to `pubspec.yaml` under `dependencies:`:
  ```yaml
  share_plus: ^10.0.0
  path_provider: ^2.1.0
  ```
- [ ] Run `flutter pub get`; confirm zero errors
- [ ] Create `lib/models/splitter_trip.dart` — `SplitterTrip` with `toMap()` (key `created_at` ISO-8601) and `fromMap`
- [ ] Create `lib/models/splitter_participant.dart` — `SplitterParticipant` with `toMap()` (key `trip_id`) and `fromMap`
- [ ] Create `lib/models/splitter_expense.dart` — `SplitterExpense`; `toMap()` emits only the six stored columns; `fromMap` sets `payerName = ''` and `shareParticipantIds = const []`
- [ ] In `database_helper.dart`: change `version: 2` → `version: 3`
- [ ] Add the four `CREATE TABLE` statements to `onCreate` (copy from spec exactly)
- [ ] Add `if (oldVersion < 3)` block in `onUpgrade` that creates all four tables with `CREATE TABLE IF NOT EXISTS`
- [ ] Add `insertSplitterTrip`, `getAllSplitterTrips`
- [ ] Add `deleteSplitterTrip`: query expense ids with `SELECT id FROM splitter_expenses WHERE trip_id = ?`; delete from `splitter_expense_shares WHERE expense_id IN (...)` (skip if empty list); delete from `splitter_expenses WHERE trip_id = ?`; delete from `splitter_participants WHERE trip_id = ?`; delete from `splitter_trips WHERE id = ?`
- [ ] Add `insertSplitterParticipant`, `participantsForTrip`
- [ ] Add `insertSplitterExpense` (expense insert + shares loop)
- [ ] Add `expensesForTrip`: raw query `SELECT e.*, p.name AS payer_name FROM splitter_expenses e JOIN splitter_participants p ON p.id = e.payer_id WHERE e.trip_id = ? ORDER BY e.date DESC, e.id DESC`; then for each expense do `await db.query('splitter_expense_shares', columns: ['participant_id'], where: 'expense_id = ?', whereArgs: [e.id])` and collect ids; return `SplitterExpense` with `payerName` and `shareParticipantIds` filled
- [ ] Add `deleteSplitterExpense` and `splitterTripTotal`
- [ ] Run `flutter analyze lib/`; fix all warnings
- [ ] Commit: `feat: add bill splitter DB schema, models, and CRUD`

---

### Task 2: Settlement service

**Files:**
- Create: `lib/services/splitter_service.dart`
- Create: `test/services/splitter_service_test.dart`

**Interfaces:**
- Consumes: `SplitterParticipant`, `SplitterExpense` from Task 1
- Produces:
  - `class Settlement { final String from; final String to; final double amount; }`
  - `List<Settlement> settle(List<SplitterParticipant> participants, List<SplitterExpense> expenses)`
    - Algorithm: for each participant compute `net = paid − owed` where `owed = Σ (double.parse((e.amount / e.shareParticipantIds.length).toStringAsFixed(4)))` for each expense they're in; separate into creditors (net > 0.005) and debtors (net < -0.005); greedy loop: pair largest-abs debtor with largest creditor, settlement = `min(debtor.abs, creditor)` rounded to 2 dp, record `Settlement`, reduce balances, remove zeros; return list

- [ ] Create `test/services/splitter_service_test.dart` with the helper setup and the five tests below; do **not** create `splitter_service.dart` yet:

```dart
// Setup helpers at top of main():
final alice = SplitterParticipant(id: 1, tripId: 1, name: 'Alice');
final bob   = SplitterParticipant(id: 2, tripId: 1, name: 'Bob');
final charlie = SplitterParticipant(id: 3, tripId: 1, name: 'Charlie');

SplitterExpense paid(int payerId, double amount, List<int> shares) =>
    SplitterExpense(tripId: 1, payerId: payerId, amount: amount,
        note: '', date: DateTime(2026), shareParticipantIds: shares);

// Test 1 – Review Focus #1
test('no expenses returns empty list', () {
  expect(settle([alice, bob], []), isEmpty);
});

// Test 2 – single payer, equal split
test('one payer two others owe equal shares', () {
  final result = settle([alice, bob, charlie], [paid(1, 300, [1, 2, 3])]);
  expect(result.length, 2);
  expect(result.any((s) => s.from == 'Bob'     && s.to == 'Alice' && (s.amount - 100).abs() < 0.01), isTrue);
  expect(result.any((s) => s.from == 'Charlie' && s.to == 'Alice' && (s.amount - 100).abs() < 0.01), isTrue);
});

// Test 3 – minimise transactions
test('multiple payers produces minimum transactions', () {
  // Alice pays 60 split Alice+Bob; Bob pays 60 split Bob+Charlie
  // net: Alice +30, Bob 0, Charlie -30 → 1 settlement
  final result = settle([alice, bob, charlie], [
    paid(1, 60, [1, 2]),
    paid(2, 60, [2, 3]),
  ]);
  expect(result.length, 1);
  expect(result.first.from, 'Charlie');
  expect(result.first.to, 'Alice');
  expect((result.first.amount - 30).abs(), lessThan(0.01));
});

// Test 4 – Review Focus #3: zero-balance participant excluded
test('zero-net participant not in settlements', () {
  // Alice pays 100 shared only with Alice; Bob has no involvement
  final result = settle([alice, bob], [paid(1, 100, [1])]);
  expect(result, isEmpty);
});

// Test 5 – Review Focus #2: all expenses by one payer
test('all expenses by one payer yields n-1 payments', () {
  final result = settle([alice, bob, charlie], [
    paid(1, 300, [1, 2, 3]),
    paid(1, 150, [1, 2, 3]),
  ]);
  // Bob owes 150, Charlie owes 150
  expect(result.length, 2);
  expect(result.every((s) => s.to == 'Alice'), isTrue);
});
```

- [ ] Run `flutter test test/services/splitter_service_test.dart`; confirm all five **fail** with an import/undefined error
- [ ] Create `lib/services/splitter_service.dart` with `Settlement` class and `settle()` function; apply the algorithm from the Interfaces block above; round per-share owed to 4 dp before summing; round final settlement amount to 2 dp; include a one-line comment: `// Floating-point: owed rounded to 4dp per share, settlement to 2dp.`
- [ ] Run `flutter test test/services/splitter_service_test.dart`; confirm all five **pass**
- [ ] Run `flutter analyze lib/services/splitter_service.dart`; fix warnings
- [ ] Commit: `feat: add settlement calculation service with unit tests`

---

### Task 3: TripListScreen

**Files:**
- Create: `lib/screens/trip_list_screen.dart`

**Interfaces:**
- Consumes: `DatabaseHelper.{insertSplitterTrip, getAllSplitterTrips, deleteSplitterTrip, splitterTripTotal, insertSplitterParticipant, participantsForTrip}`; `SplitterTrip`, `SplitterParticipant`
- Produces: `class TripListScreen extends StatefulWidget` — `const TripListScreen({super.key})`; navigates to `TripDetailScreen(trip: trip, participants: participants)` on tap (import stub — screen created in Task 5, add import once that task is done; for now, add a `// TODO: navigate` comment)

- [ ] Create `lib/screens/trip_list_screen.dart` as `StatefulWidget`
- [ ] State fields: `List<SplitterTrip> _trips = []`, `Map<int,List<SplitterParticipant>> _participants = {}`, `Map<int,double> _totals = {}`, `bool _loading = true`
- [ ] `_load()`: `getAllSplitterTrips()`, then for each trip fetch `participantsForTrip` and `splitterTripTotal`; set state
- [ ] `build`: `Scaffold` with `AppBar(title: const Text('Trips', style: TextStyle(fontWeight: FontWeight.bold)))`, `floatingActionButton: FloatingActionButton(onPressed: _createTrip, child: const Icon(Icons.add))`
- [ ] Loading state: `CircularProgressIndicator`
- [ ] Empty state: centered `Column` — `Icons.group_outlined` (size 72, `cs.outlineVariant`), `'No trips yet'` (w500, 16), `'Tap + to start a trip'` (`cs.outline`, 14)
- [ ] Trip list: `ListView.builder`; each item is `Dismissible(direction: endToStart, background: red error container delete background matching household_screen style, confirmDismiss: _confirmDelete, onDismissed: deleteSplitterTrip + _load)`; child is `Card` → `InkWell(onTap: navigate)` → `Padding(16,12)` → `Column`: trip name (w600, 15), participant names joined by `' · '` (`cs.outline`, 12, ellipsis), `'Total: $currency ${money.format(total)}'` (`cs.primary`, 13, right-align)
- [ ] `_createTrip()`: `showDialog` with `Form`; two `TextFormField`s: trip name (required) and participants (`hintText: 'Alice, Bob, Charlie'`, validator requires at least 2 names after split/trim); on save: `insertSplitterTrip` → get `tripId` → `name.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)` → `insertSplitterParticipant` for each → `_load()`; currency symbol loaded from `db.getSetting('currency', 'Rs.')`
- [ ] `_confirmDelete()`: returns `showDialog<bool>` with Cancel / Delete actions (same pattern as home_screen)
- [ ] Run `flutter analyze lib/screens/trip_list_screen.dart`; fix warnings
- [ ] Commit: `feat: add TripListScreen`

---

### Task 4: AddTripExpenseScreen

**Files:**
- Create: `lib/screens/add_trip_expense_screen.dart`

**Interfaces:**
- Consumes: `DatabaseHelper.insertSplitterExpense`; `SplitterParticipant`, `SplitterExpense`
- Produces: `class AddTripExpenseScreen extends StatefulWidget` — `const AddTripExpenseScreen({super.key, required this.tripId, required this.participants})`; pops `true` on successful save

- [ ] Create `lib/screens/add_trip_expense_screen.dart` as `StatefulWidget` with `final int tripId` and `final List<SplitterParticipant> participants`
- [ ] State: `late int _payerId` (init to `participants.first.id!`), `_amount` and `_note` `TextEditingController`s, `Set<int> _involved` (init to `{...participants.map((p) => p.id!)}`), `final _form = GlobalKey<FormState>()`
- [ ] `build`: `Scaffold` with `AppBar(title: Text('Add Expense'))`, body is `Form` in `ListView(padding: all 16)`
- [ ] Payer: `DropdownButtonFormField<int>` — items from `participants`, `value: _payerId`, `onChanged` sets `_payerId`, `decoration: InputDecoration(labelText: 'Who paid?')`
- [ ] Amount: `TextFormField`, `keyboardType: numberWithOptions(decimal: true)`, `decoration: InputDecoration(labelText: 'Amount')`, validator: `double.tryParse` must be non-null and > 0
- [ ] Note: `TextFormField`, `decoration: InputDecoration(labelText: 'Note (optional)')`
- [ ] Split section: `Text('Split between', style: TextStyle(fontSize: 13, color: cs.outline))`, then `Wrap(spacing: 8, runSpacing: 8)` of `FilterChip` per participant — `selected: _involved.contains(p.id!)`, `onSelected: (v) => setState(() => v ? _involved.add(p.id!) : _involved.remove(p.id!))`
- [ ] `FilledButton` `'Add Expense'`: validates form; if `_involved.isEmpty` shows `ScaffoldMessenger` snackbar "Select at least one person" and returns; otherwise builds `SplitterExpense(tripId: tripId, payerId: _payerId, amount: double.parse(_amount.text), note: _note.text.trim(), date: DateTime.now(), shareParticipantIds: _involved.toList())`, `insertSplitterExpense`, `Navigator.pop(context, true)`
- [ ] `dispose`: dispose controllers
- [ ] Run `flutter analyze lib/screens/add_trip_expense_screen.dart`; fix warnings
- [ ] Commit: `feat: add AddTripExpenseScreen`

---

### Task 5: TripDetailScreen

**Files:**
- Create: `lib/screens/trip_detail_screen.dart`

**Interfaces:**
- Consumes: `DatabaseHelper.{expensesForTrip, deleteSplitterExpense}`; `settle()` and `Settlement` from `splitter_service.dart`; `Share.share`, `Share.shareXFiles`; `AddTripExpenseScreen` from Task 4; `SplitterTrip`, `SplitterParticipant`, `SplitterExpense`
- Produces: `class TripDetailScreen extends StatefulWidget` — `const TripDetailScreen({super.key, required this.trip, required this.participants})`

- [ ] Create `lib/screens/trip_detail_screen.dart` as `StatefulWidget with SingleTickerProviderStateMixin`
- [ ] State: `late TabController _tabController`, `List<SplitterExpense> _expenses = []`, `bool _loading = true`, `final _repaintKey = GlobalKey()`, currency string loaded from settings
- [ ] `initState`: create `TabController(length: 2, vsync: this)`, add listener `_tabController.addListener(() => setState((){}))` (drives FAB visibility), call `_load()`
- [ ] `_load()`: `expensesForTrip(trip.id!)` + `getSetting('currency', 'Rs.')`, set state
- [ ] `build`: `Scaffold`, `AppBar` with `title: Text(trip.name, style: TextStyle(fontWeight: FontWeight.bold))` and `bottom: TabBar(controller: _tabController, tabs: [Tab(text:'Expenses'), Tab(text:'Settlements')])`; `body: TabBarView(controller: _tabController, children: [_expensesTab(), _settlementsTab()])`; `floatingActionButton` returns `_buildFab()`
- [ ] `_buildFab()`: if `_tabController.index == 0` return `FloatingActionButton(onPressed: _addExpense, child: Icon(Icons.add))`; if index == 1 and `_settlements().isNotEmpty` return `FloatingActionButton.extended(icon: Icon(Icons.share_outlined), label: Text('Share'), onPressed: _shareSettlements)`; else return `null`
- [ ] `_settlements()` (getter): calls `settle(widget.participants, _expenses)`, cached or computed inline
- [ ] `_expensesTab()`: if loading → `CircularProgressIndicator`; if empty → centered column `Icons.receipt_long_outlined` (72, outlineVariant), `'No expenses yet'`, `'Tap + to add one'`; else `ListView.builder` with `Dismissible` cards (same pattern as household_screen): each card shows payer name (w600), amount (`cs.primary`, bold), note (`cs.outline`, 12), `'split ${e.shareParticipantIds.length} ways'` (`cs.outline`, 12); swipe-to-delete calls `_deleteExpense`
- [ ] `_settlementsTab()`: compute `final settlements = _settlements()`; if empty → centered `Icons.check_circle_outline_rounded` (72, `cs.primary`), `'All even!'`; else `ListView` of settlement rows inside `RepaintBoundary(key: _repaintKey)` — each row is `Padding` with `Row`: `Text(s.from)`, `Icon(Icons.arrow_forward_rounded, size:16, color:cs.outline)`, `Text(s.to)`, `Spacer()`, `Text('$currency ${money.format(s.amount)}', style: bold, cs.primary)`
- [ ] `_addExpense()`: push `AddTripExpenseScreen(tripId: trip.id!, participants: widget.participants)`; on `true` call `_load()`
- [ ] `_deleteExpense(SplitterExpense e)`: confirm dialog → `deleteSplitterExpense(e.id!)` → `_load()`
- [ ] `_shareSettlements()`: shows `showModalBottomSheet` with two `ListTile`s:
  - "Share as text" (`Icons.text_fields_outlined`) → `Navigator.pop` then `Share.share(_buildShareText())`
  - "Share as image" (`Icons.image_outlined`) → `Navigator.pop` then `_shareImage()`
- [ ] `_buildShareText()`: returns multi-line string:
  ```
  Trip: {trip.name}
  Total: {currency} {money.format(totalSpent)}
  Participants: {names joined ', '}

  Settlements:
  • {s.from} → {s.to}: {currency} {money.format(s.amount)}
  ...
  ```
- [ ] `_shareImage()`: `final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary`; `final image = await boundary.toImage(pixelRatio: 3.0)`; `final byteData = await image.toByteData(format: ui.ImageByteFormat.png)`; `final bytes = byteData!.buffer.asUint8List()`; `final dir = await getTemporaryDirectory()`; write to `'${dir.path}/budgie_settlement.png'`; `await Share.shareXFiles([XFile(file.path)])`; imports needed: `dart:ui as ui`, `dart:io`, `package:path_provider/path_provider.dart`, `package:share_plus/share_plus.dart`
- [ ] Update `TripListScreen` in Task 3: replace the `// TODO: navigate` comment with `Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t, participants: _participants[t.id!] ?? [])))` and add the import
- [ ] Run `flutter analyze lib/screens/trip_detail_screen.dart lib/screens/trip_list_screen.dart`; fix warnings
- [ ] Commit: `feat: add TripDetailScreen with settlements and sharing`

---

### Task 6: Wire into RootScreen

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `TripListScreen` from Task 3
- Produces: three-tab `RootScreen`

- [ ] Add import `import 'screens/trip_list_screen.dart';` to `lib/main.dart`
- [ ] In `_RootScreenState.build`, add `TripListScreen()` at index 2 in the `IndexedStack` children list
- [ ] Add third `NavigationDestination` to the `NavigationBar`:
  ```dart
  const NavigationDestination(
    icon: Icon(Icons.receipt_long_outlined),
    selectedIcon: Icon(Icons.receipt_long),
    label: 'Split',
  ),
  ```
- [ ] Run `flutter analyze lib/`; confirm **zero issues**
- [ ] Run app on device/emulator; verify end-to-end: three tabs visible → Split tab shows empty state → create trip with participants → add expenses → Settlements tab shows correct debts → Share opens bottom sheet → text share sends summary → image share sends PNG
- [ ] Commit: `feat: wire bill splitter tab into RootScreen`
