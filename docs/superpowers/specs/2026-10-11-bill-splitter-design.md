# Bill Splitter Design

**Date:** 2026-10-11  
**Status:** Approved for implementation

---

## Intent

Add a Bill Splitter tab to Budgie. A group of friends on a trip log who paid for what; the app calculates the minimum set of payments to settle all debts. Results are shareable as plain text and as a screenshot.

**Success criteria:**
- Create a named trip with arbitrary participants (names only, no accounts)
- Add expenses: who paid, amount, note, which participants split it (equal shares)
- See a settlement screen: who pays whom, how much
- Share the settlement as text (WhatsApp/messages) and as an image

---

## Architecture

### Navigation

`RootScreen` gains a third tab: **Split** (`Icons.receipt_long_outlined` / `Icons.receipt_long`). The `IndexedStack` adds `TripListScreen()` at index 2.

### Screen flow

```
TripListScreen  ──(tap trip)──►  TripDetailScreen
     │                               │  tabs: Expenses | Settlements
     │ (FAB)                         │
     ▼                               │ (FAB)
  create-trip dialog                 ▼
                                AddTripExpenseScreen
```

**TripListScreen** — lists all trips (most recent first). Each card shows trip name, participant count, total spent, creation date. FAB opens an inline `showDialog` to enter trip name and comma-separated participant names. Swipe-to-delete with confirm dialog.

**TripDetailScreen** — `DefaultTabController` with two tabs:
- *Expenses tab*: `ListView` of expense cards (payer, amount, note, "split N ways"). Swipe-to-delete.
- *Settlements tab*: list of "X → Y  Rs. amount" rows + a share FAB (extended, bottom-right). The settlement card is wrapped in a `RepaintBoundary` with a `GlobalKey` for image capture.

**AddTripExpenseScreen** — full screen (not a bottom sheet, to give room for the participant checkboxes). Fields: who paid (dropdown), amount, note (optional), who's involved (multi-select checkboxes, default all checked). Save → pops with `true`.

---

## Data Model

Four new SQLite tables. DB version bumps **2 → 3**.

```sql
CREATE TABLE splitter_trips (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  created_at  TEXT NOT NULL   -- ISO-8601
);

CREATE TABLE splitter_participants (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  trip_id  INTEGER NOT NULL REFERENCES splitter_trips(id),
  name     TEXT NOT NULL
);

CREATE TABLE splitter_expenses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  trip_id     INTEGER NOT NULL REFERENCES splitter_trips(id),
  payer_id    INTEGER NOT NULL REFERENCES splitter_participants(id),
  amount      REAL NOT NULL,
  note        TEXT NOT NULL DEFAULT '',
  date        TEXT NOT NULL   -- ISO-8601
);

CREATE TABLE splitter_expense_shares (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  expense_id     INTEGER NOT NULL REFERENCES splitter_expenses(id),
  participant_id INTEGER NOT NULL REFERENCES splitter_participants(id)
);
```

Migration in `onUpgrade`: `if (oldVersion < 3)` creates all four tables.

### Dart model classes

**`lib/models/splitter_trip.dart`**
```dart
class SplitterTrip {
  final int? id;
  final String name;
  final DateTime createdAt;
}
```

**`lib/models/splitter_participant.dart`**
```dart
class SplitterParticipant {
  final int? id;
  final int tripId;
  final String name;
}
```

**`lib/models/splitter_expense.dart`**
```dart
class SplitterExpense {
  final int? id;
  final int tripId;
  final int payerId;
  final double amount;
  final String note;
  final DateTime date;
  // populated on load, not stored:
  final String? payerName;
  final List<int> shareParticipantIds;
}
```

---

## Database Methods (additions to DatabaseHelper)

```
// Trips
insertTrip(SplitterTrip) → int id
getAllTrips() → List<SplitterTrip>  (ORDER BY created_at DESC)
deleteTrip(int id)  -- cascades: delete participants, expenses, shares

// Participants
insertParticipant(SplitterParticipant) → int id
participantsForTrip(int tripId) → List<SplitterParticipant>

// Expenses
insertExpense(SplitterExpense) → int id  -- also inserts shares
expensesForTrip(int tripId) → List<SplitterExpense>  -- joins payer name, loads shares
deleteSplitterExpense(int id)  -- also deletes shares

// Summary helper
tripTotal(int tripId) → double
```

`deleteTrip` deletes in order: shares → expenses → participants → trip (no FK cascade in SQLite by default).

---

## Settlement Algorithm

Implemented as a pure function in `lib/services/splitter_service.dart`:

```
List<Settlement> settle(List<SplitterParticipant> participants,
                        List<SplitterExpense> expenses)
```

**Steps:**
1. For each participant, compute net balance:  
   `balance = Σ(expenses where payer = p) − Σ(expense.amount / shareCount for each expense p is in)`
2. Separate into creditors (balance > 0) and debtors (balance < 0), sorted by absolute value descending.
3. Greedy loop: pair largest debtor with largest creditor. Payment = `min(|debtor|, creditor)`. Record `Settlement(from: debtor, to: creditor, amount: payment)`. Reduce both balances. Remove when zero.
4. Returns `List<Settlement>` — at most `n − 1` transactions.

```dart
class Settlement {
  final String from;
  final String to;
  final double amount;
}
```

---

## Sharing

**Text share** (`share_plus`):
```
Trip: Paris Weekend
Total: Rs. 15,000.00
Participants: Alice, Bob, Charlie

Settlements:
• Bob → Alice: Rs. 3,200.00
• Charlie → Bob: Rs. 800.00
```
Called via `Share.share(text)`.

**Image share**: The settlement list widget is wrapped in a `RepaintBoundary(key: _repaintKey)`. On tap:
1. `RenderRepaintBoundary.toImage(pixelRatio: 3.0)`
2. Encode to PNG bytes via `image.toByteData(format: ImageByteFormat.png)`
3. Write to `path_provider` temp dir as `settlement.png`
4. Share via `Share.shareXFiles([XFile(path)])`

`share_plus` and `path_provider` are the only new dependencies. `path_provider` is very likely already present — check; add only if missing.

---

## Files Changed / Created

| File | Change |
|---|---|
| `pubspec.yaml` | add `share_plus: ^10.0.0` (and `path_provider` if not present) |
| `lib/db/database_helper.dart` | bump version to 3, add 4 tables + migration, add splitter CRUD methods |
| `lib/main.dart` (RootScreen) | add third tab to `IndexedStack` and `NavigationBar` |
| `lib/models/splitter_trip.dart` | new |
| `lib/models/splitter_participant.dart` | new |
| `lib/models/splitter_expense.dart` | new |
| `lib/services/splitter_service.dart` | new — pure `settle()` function |
| `lib/screens/trip_list_screen.dart` | new |
| `lib/screens/trip_detail_screen.dart` | new |
| `lib/screens/add_trip_expense_screen.dart` | new |

---

## Out of scope

- Editing an existing expense (delete and re-add)
- Currency conversion
- Unequal custom amounts per person (percentage or fixed)
- Push notifications or reminders
- Exporting to the existing Budgie expense log
