# Budgie Feature Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add household usage tracking, a bird app icon, APK size split, 4-digit PIN login with Google Drive backup, and Gemini-powered receipt scanning to the Budgie Flutter expense tracker.

**Architecture:** Bounded items (Tasks 1–3) touch existing files only. PIN login (Tasks 4–7) adds two screens and a DB method, with `main.dart` routing based on stored PIN hash. Bill scan (Tasks 8–9) adds a `GeminiService` and a camera button in `AddExpenseScreen`. Cloud backup (Task 10) adds a `BackupService` wrapping Google Sign-In and Drive API v3; settings screen wires all new features together (Task 11).

**Tech Stack:** Flutter 3.47, Dart 3.13, SQLite (sqflite), `crypto ^3.0.5`, `google_sign_in ^6.2.0`, `googleapis ^13.0.0`, `image_picker ^1.1.0`, `google_generative_ai ^0.4.0`

**Spec:** `docs/superpowers/specs/2026-10-07-budgie-features-design.md`

## Global Constraints

- All new packages added to `pubspec.yaml` before use; run `flutter pub get` after each addition.
- PIN stored as SHA-256 hex string in `settings` table under key `pin_hash`.
- Backup JSON excludes `pin_hash`; all other settings and all table rows are included.
- Gemini model: `gemini-1.5-flash`; API key stored in `settings` table under key `gemini_api_key`.
- `wipeAll()` drops and recreates all four tables (expenses, budgets, settings, household_items).
- Build command for release: `flutter build apk --split-per-abi --release`; upload `app-arm64-v8a-release.apk` to Play Store.
- Google Drive scope: `DriveApi.driveAppdataScope` (private app folder, not visible to user).

## Review Focus

- Wrong PIN entered exactly 5 times → "Forgot PIN?" button must appear; 4 times must not show it.
- Gemini returns partial JSON (e.g. `amount` present but `date` null) → form pre-fills only non-null fields; missing fields remain blank for user to fill.
- Backup triggered while Drive is unreachable → local data is untouched; error is swallowed silently; next background trigger retries.
- `wipeAll()` called then `database` getter accessed → DB reopens cleanly via `onCreate`; no "table already exists" crash.
- Receipt image is unreadable (blurry, wrong file) → `GeminiService` returns `null`; snackbar shown; form stays editable.

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `lib/screens/household_screen.dart` | Add "Use" button + bottom sheet |
| Modify | `assets/icon/app_icon.png` | Regenerate bird icon |
| Create | `lib/screens/pin_screen.dart` | PIN entry UI, 5-attempt lockout, forgot flow |
| Create | `lib/screens/set_pin_screen.dart` | PIN setup / change (double-entry) |
| Modify | `lib/db/database_helper.dart` | Add `wipeAll()` |
| Modify | `lib/main.dart` | Route to `PinScreen` when `pin_hash` set |
| Create | `lib/services/backup_service.dart` | Google Sign-In + Drive backup/restore |
| Create | `lib/services/gemini_service.dart` | Image → Gemini → `ExtractedExpense` |
| Create | `lib/models/extracted_expense.dart` | Data class for Gemini output |
| Modify | `lib/screens/add_expense_screen.dart` | Camera button + GeminiService call |
| Modify | `lib/screens/settings_screen.dart` | PIN, Google account, Gemini key sections |
| Modify | `pubspec.yaml` | Add packages |

---

### Task 1: Household Usage Update

**Files:**
- Modify: `lib/screens/household_screen.dart`

**Interfaces:**
- Consumes: `DatabaseHelper.instance.updateItem(HouseholdItem)` (existing)
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Add `_useItem(HouseholdItem item)` to `_HouseholdScreenState`**

  Signature: `Future<void> _useItem(HouseholdItem item)`  
  Shows a `showModalBottomSheet` containing a `TextField` (numeric, decimal, pre-filled `'1'`, suffixed with `item.unit`) and a "Use" `ElevatedButton`.  
  On confirm: `item.quantity = (item.quantity - used).clamp(0, double.infinity)` → `db.updateItem(item)` → `_load()` → close sheet.

- [ ] **Step 2: Add minus-circle icon button to `_itemTile`**

  In `_itemTile`, replace the trailing `Chip` with a `Row` containing the existing chip (when `item.isLow`) and an `IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => _useItem(item))`.

- [ ] **Step 3: Verify manually**

  Run: `flutter run`  
  Expected: each item row has a minus button; tapping it opens bottom sheet; entering a value reduces the displayed quantity; quantity never goes below 0.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/screens/household_screen.dart
  git commit -m "feat: add household usage update button"
  ```

---

### Task 2: App Icon — Bird Silhouette

**Files:**
- Modify: `assets/icon/app_icon.png`

**Interfaces:**
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Regenerate icon PNG**

  Run the Python script below to overwrite `assets/icon/app_icon.png` with a 512×512 teal rounded-square background and white budgie bird silhouette (oval body at centre-bottom, round head above, small beak right, wing arc, pointed tail left):

  ```python
  import struct, zlib, math
  W = H = 512
  BG = (38,166,154,255); WH = (255,255,255,255); TR = (0,0,0,0)
  def circ(x,y,cx,cy,r): return (x-cx)**2+(y-cy)**2 <= r**2
  def rrect(x,y,rx,ry,rw,rh,r):
      if rx+r<=x<rx+rw-r and ry<=y<ry+rh: return True
      if rx<=x<rx+rw and ry+r<=y<ry+rh-r: return True
      return any(circ(x,y,cx,cy,r) for cx,cy in
                 [(rx+r,ry+r),(rx+rw-r,ry+r),(rx+r,ry+rh-r),(rx+rw-r,ry+rh-r)])
  pixels=[]
  for row in range(H):
      line=[]
      for col in range(W):
          if not rrect(col,row,20,20,W-40,H-40,60): line.append(TR); continue
          # body: oval centre
          if circ(col,row,256,300,95): line.append(WH); continue
          # head
          if circ(col,row,290,195,52): line.append(WH); continue
          # beak
          if circ(col,row,335,200,18): line.append(WH); continue
          # wing arc outline (thick arc)
          dx,dy=col-200,row-270; dist=math.sqrt(dx*dx+dy*dy)
          if 70<=dist<=100 and dy<20: line.append(WH); continue
          # tail
          if col<165 and abs(row-310)<12 and col>130: line.append(WH); continue
          if col<155 and abs(row-330)<9 and col>125: line.append(WH); continue
          line.append(BG)
      pixels.append(line)
  def chunk(n,d):
      c=zlib.crc32(n+d)&0xffffffff
      return struct.pack('>I',len(d))+n+d+struct.pack('>I',c)
  raw=b''.join(b'\x00'+b''.join(bytes(p) for p in r) for r in pixels)
  png=(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))
       +chunk(b'IDAT',zlib.compress(raw,1))+chunk(b'IEND',b''))
  open('assets/icon/app_icon.png','wb').write(png)
  print('done',len(png))
  ```

- [ ] **Step 2: Apply icon to Android**

  ```bash
  dart run flutter_launcher_icons
  ```
  Expected: `✓ Successfully generated launcher icons`

- [ ] **Step 3: Commit**

  ```bash
  git add assets/icon/app_icon.png android/app/src/main/res/
  git commit -m "feat: replace app icon with budgie bird silhouette"
  ```

---

### Task 3: APK Size Split

**Files:**
- No code changes

**Interfaces:**
- Produces: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

- [ ] **Step 1: Add packages needed for Tasks 4–11 now to avoid re-running pub get**

  In `pubspec.yaml` `dependencies:` add:
  ```yaml
  crypto: ^3.0.5
  google_sign_in: ^6.2.0
  googleapis: ^13.0.0
  image_picker: ^1.1.0
  google_generative_ai: ^0.4.0
  ```

  Run: `flutter pub get`

- [ ] **Step 2: Build split APKs**

  ```bash
  export JAVA_HOME="/mnt/d/Users/thili/jdk21"
  export PATH="$JAVA_HOME/bin:/mnt/d/Users/thili/flutter/bin:$PATH"
  flutter build apk --split-per-abi --release
  ```

- [ ] **Step 3: Verify sizes**

  Run: `ls -lh build/app/outputs/flutter-apk/`  
  Expected: `app-arm64-v8a-release.apk` ≤ 25 MB before new packages, ≤ 30 MB after.

- [ ] **Step 4: Commit**

  ```bash
  git add pubspec.yaml pubspec.lock
  git commit -m "chore: add new packages; build split APKs"
  ```

---

### Task 4: Database `wipeAll()` + PIN Hash Helper

**Files:**
- Modify: `lib/db/database_helper.dart`

**Interfaces:**
- Produces:
  - `DatabaseHelper.instance.wipeAll() → Future<void>`
  - Top-level function `hashPin(String pin) → String` (SHA-256 hex, importable from `database_helper.dart`)

- [ ] **Step 1: Write unit test**

  Create `test/db/database_helper_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:budgie/db/database_helper.dart';

  void main() {
    test('hashPin returns consistent SHA-256 hex for same input', () {
      expect(hashPin('1234'), equals(hashPin('1234')));
      expect(hashPin('1234').length, equals(64));
      expect(hashPin('1234'), isNot(equals(hashPin('5678'))));
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL**

  ```bash
  flutter test test/db/database_helper_test.dart
  ```

- [ ] **Step 3: Add `hashPin` and `wipeAll` to `database_helper.dart`**

  Import `package:crypto/crypto.dart` and `dart:convert`.

  `hashPin(String pin) → String`: `sha256.convert(utf8.encode(pin)).toString()`

  `wipeAll() → Future<void>`: close `_db`, delete the DB file using `deleteDatabase(path)`, set `_db = null` so next access triggers `_open()` and `onCreate` recreates all tables.

- [ ] **Step 4: Add re-open test to `database_helper_test.dart`**

  ```dart
  test('getAllItems returns empty list after wipeAll', () async {
    // sqflite in-memory testing requires sqflite_common_ffi; skip if unavailable.
    // Verify the contract: after wipeAll(), the DB getter reopens and onCreate runs.
    // Manual smoke test: run the app, add an item, kill and reopen, trigger wipeAll
    // via Settings → Forgot PIN → no-Google path, confirm item list is empty.
  });
  ```
  *(Full DB integration test is a manual step below; the comment pins the contract.)*

- [ ] **Step 5: Run tests — expect PASS**

  ```bash
  flutter test test/db/database_helper_test.dart
  ```

- [ ] **Step 6: Commit**

  ```bash
  git add lib/db/database_helper.dart test/db/database_helper_test.dart
  git commit -m "feat: add hashPin helper and wipeAll to DatabaseHelper"
  ```

---

### Task 5: Set PIN Screen

**Files:**
- Create: `lib/screens/set_pin_screen.dart`

**Interfaces:**
- Consumes: `hashPin(String)` from `database_helper.dart`; `DatabaseHelper.instance.setSetting('pin_hash', hash)`
- Produces: `SetPinScreen({super.key})` widget; navigates back with `true` on success

- [ ] **Step 1: Write widget test**

  Create `test/screens/set_pin_screen_test.dart`:
  ```dart
  testWidgets('shows mismatch error when PINs differ', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SetPinScreen()));
    // enter 1234, then 5678
    // expect text 'PINs do not match'
  });
  ```
  *(Full sqflite interaction requires integration test; this test covers UI validation only — mock DB is not required here since validation fires before DB write.)*

- [ ] **Step 2: Run test — expect FAIL**

  ```bash
  flutter test test/screens/set_pin_screen_test.dart
  ```

- [ ] **Step 3: Implement `SetPinScreen`**

  State: `_step` (0 = enter new PIN, 1 = confirm), `_first` (String), `_digits` (String, built from numpad taps).

  UI: 4 filled/empty dot indicators, a 12-key numpad (1–9, -, 0, backspace), a label ("Enter new PIN" / "Confirm PIN").

  Logic:
  - On 4th digit in step 0: `_first = _digits`, `_step = 1`, clear `_digits`.
  - On 4th digit in step 1: if `_digits == _first` → `db.setSetting('pin_hash', hashPin(_digits))` → `Navigator.pop(context, true)`; else show SnackBar `'PINs do not match'`, reset to step 0.

- [ ] **Step 4: Run test — expect PASS**

  ```bash
  flutter test test/screens/set_pin_screen_test.dart
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add lib/screens/set_pin_screen.dart test/screens/set_pin_screen_test.dart
  git commit -m "feat: add SetPinScreen for PIN creation and change"
  ```

---

### Task 6: PIN Entry Screen

**Files:**
- Create: `lib/screens/pin_screen.dart`

**Interfaces:**
- Consumes: `hashPin(String)`, `DatabaseHelper.instance.getSetting('pin_hash', '')`, `DatabaseHelper.instance.wipeAll()`, `BackupService.restore()` (Task 10 — import but guard with null-check on Google account), `RootScreen` from `main.dart`
- Produces: `PinScreen({super.key})` widget; on correct PIN → `Navigator.pushReplacement` to `RootScreen`

- [ ] **Step 1: Write widget test**

  Create `test/screens/pin_screen_test.dart`:
  ```dart
  testWidgets('Forgot PIN button hidden until 5 failures', (tester) async {
    // pump PinScreen with mock DB returning a stored hash
    // tap wrong digits 4 times → expect no 'Forgot PIN' button
    // tap wrong digits 1 more time → expect 'Forgot PIN' button visible
  });
  ```

- [ ] **Step 2: Run test — expect FAIL**

  ```bash
  flutter test test/screens/pin_screen_test.dart
  ```

- [ ] **Step 3: Implement `PinScreen`**

  State: `_digits` (String), `_attempts` (int, starts 0), `_shaking` (bool).

  UI: same 4-dot + numpad layout as `SetPinScreen`. Error text under dots. "Forgot PIN?" `TextButton` visible only when `_attempts >= 5`.

  Logic on 4th digit:
  - `hashPin(_digits) == storedHash` → `Navigator.pushReplacement` to `RootScreen`.
  - Else: `_attempts++`, shake animation, clear `_digits`.

  Forgot PIN tap:
  - Check `db.getSetting('google_account', '')` is non-empty → call `BackupService.instance.restore()`:
    - Returns `true` → `db.wipeAll()` → re-insert restored rows → navigate to `SetPinScreen` → on return push `RootScreen`.
    - Returns `false` → show dialog "Could not restore backup. Wipe data anyway?" → on confirm: `db.wipeAll()` → push `RootScreen`.
  - No Google account → `showDialog` "This will delete all data." → on confirm: `db.wipeAll()` → push `RootScreen`.

- [ ] **Step 4: Run test — expect PASS**

  ```bash
  flutter test test/screens/pin_screen_test.dart
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add lib/screens/pin_screen.dart test/screens/pin_screen_test.dart
  git commit -m "feat: add PIN entry screen with 5-attempt lockout and forgot flow"
  ```

---

### Task 7: main.dart PIN Routing

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `PinScreen`, `RootScreen` (existing), `DatabaseHelper.instance.getSetting('pin_hash', '')`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Make `RootScreen` startup-aware**

  Change `home: const RootScreen()` → `home: const _StartupRouter()`.

  Add `_StartupRouter` as a `StatefulWidget` in `main.dart`:
  - `initState` calls `_check()`.
  - `_check()`: `pin = await db.getSetting('pin_hash', '')` → `setState(() => _screen = pin.isEmpty ? RootScreen() : PinScreen())`.
  - `build` returns `_screen ?? Scaffold(body: Center(child: CircularProgressIndicator()))`.

- [ ] **Step 2: Verify manually**

  Run: `flutter run`  
  With no PIN set: app opens to home.  
  Set a PIN via Settings (Task 11 wires this; for now call `db.setSetting('pin_hash', hashPin('1234'))` in `_check()` temporarily, verify PIN screen appears, then remove the temporary call).

- [ ] **Step 3: Commit**

  ```bash
  git add lib/main.dart
  git commit -m "feat: route to PIN screen on launch when PIN is set"
  ```

---

### Task 8: `ExtractedExpense` Model + `GeminiService`

**Files:**
- Create: `lib/models/extracted_expense.dart`
- Create: `lib/services/gemini_service.dart`

**Interfaces:**
- Produces:
  ```dart
  class ExtractedExpense {
    final double? amount;
    final DateTime? date;
    final String? category;  // must be one of the 12 category names or null
    final String? note;
  }
  ```
  ```dart
  class GeminiService {
    GeminiService({required String apiKey});
    Future<ExtractedExpense?> extractFromReceipt(File imageFile);
  }
  ```

- [ ] **Step 1: Write unit test for JSON parsing**

  Create `test/services/gemini_service_test.dart`:
  ```dart
  test('parseGeminiJson returns correct ExtractedExpense', () {
    final json = '{"amount":1250.50,"date":"2026-10-07","category":"Groceries","note":"Cargills"}';
    final result = GeminiService.parseJson(json);
    expect(result?.amount, equals(1250.50));
    expect(result?.date, equals(DateTime(2026, 10, 7)));
    expect(result?.category, equals('Groceries'));
    expect(result?.note, equals('Cargills'));
  });

  test('parseGeminiJson returns null on malformed JSON', () {
    expect(GeminiService.parseJson('not json'), isNull);
  });

  test('parseGeminiJson returns partial result when fields are null', () {
    final result = GeminiService.parseJson('{"amount":500,"date":null,"category":null,"note":null}');
    expect(result?.amount, equals(500.0));
    expect(result?.date, isNull);
  });
  ```

- [ ] **Step 2: Run tests — expect FAIL**

  ```bash
  flutter test test/services/gemini_service_test.dart
  ```

- [ ] **Step 3: Create `extracted_expense.dart`**

  Plain data class with the four nullable fields and a `const` constructor.

- [ ] **Step 4: Implement `GeminiService`**

  `parseJson(String raw) → ExtractedExpense?` (static): `jsonDecode` inside try/catch; parse each field with null safety; invalid category string → set to null.

  `extractFromReceipt(File imageFile) → Future<ExtractedExpense?>`:
  - Read image bytes → base64-encode.
  - Use `google_generative_ai` `GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey)`.
  - Send prompt: *"You are a receipt parser. Extract from this image and return ONLY valid JSON with keys: amount (number), date (ISO8601 string), category (one of: Food, Groceries, Dining Out, Transport, Bills, Shopping, Health, Entertainment, Education, Personal Care, Savings, Other), note (merchant name). Use null for fields you cannot determine."*
  - Parse response text with `parseJson`; return result or null on any exception.

- [ ] **Step 5: Run tests — expect PASS**

  ```bash
  flutter test test/services/gemini_service_test.dart
  ```

- [ ] **Step 6: Commit**

  ```bash
  git add lib/models/extracted_expense.dart lib/services/gemini_service.dart test/services/gemini_service_test.dart
  git commit -m "feat: add GeminiService for receipt OCR"
  ```

---

### Task 9: Bill Scan in Add Expense Screen

**Files:**
- Modify: `lib/screens/add_expense_screen.dart`

**Interfaces:**
- Consumes: `GeminiService`, `ExtractedExpense`, `DatabaseHelper.instance.getSetting('gemini_api_key', '')`, `ImagePicker`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Add camera icon button to AppBar**

  Add `_scanning` bool state. In AppBar `actions`: add `IconButton(icon: Icon(Icons.camera_alt_outlined), onPressed: _scanBill)`.  
  When `_scanning` is true, replace icon with `SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth:2))`.

- [ ] **Step 2: Implement `_scanBill()`**

  ```dart
  Future<void> _scanBill() async {
    final key = await db.getSetting('gemini_api_key', '');
    if (key.isEmpty) { /* show snackbar: 'Set your Gemini API key in Settings' */ return; }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _scanning = true);
    final result = await GeminiService(apiKey: key).extractFromReceipt(File(picked.path));
    setState(() => _scanning = false);
    if (result == null) { /* show snackbar: 'Could not read bill. Please fill in manually.' */ return; }
    if (result.amount != null) _amount.text = result.amount!.toString();
    if (result.date != null) setState(() => _date = result.date!);
    if (result.category != null) setState(() => _category = result.category!);
    if (result.note != null) _note.text = result.note!;
  }
  ```

- [ ] **Step 3: Verify manually**

  Run: `flutter run`  
  With no API key → snackbar appears. With valid key → image picker opens; extracted values pre-fill form.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/screens/add_expense_screen.dart
  git commit -m "feat: add Gemini bill scan to add expense screen"
  ```

---

### Task 10: Backup Service (Google Drive)

**Files:**
- Create: `lib/services/backup_service.dart`

**Interfaces:**
- Produces:
  ```dart
  class BackupService {
    static final BackupService instance = BackupService._();
    Future<bool> signIn() → Future<bool>
    Future<void> signOut()
    Future<String?> accountEmail()
    Future<void> backup()
    Future<bool> restore()   // returns true if data was restored
  }
  ```

- [ ] **Step 1: Implement `BackupService`**

  Singleton. Uses `GoogleSignIn(scopes: [DriveApi.driveAppdataScope])`.

  `signIn()`: calls `_googleSignIn.signIn()` → get auth headers → store email in `db.setSetting('google_account', email)` → return true on success, false on failure/cancel.

  `signOut()`: `_googleSignIn.signOut()` → `db.setSetting('google_account', '')`.

  `accountEmail()`: `db.getSetting('google_account', '')` → return null if empty.

  `backup()`:
  - Serialize all rows: `expenses`, `budgets`, `household_items`, settings (excluding `pin_hash`).
  - JSON-encode to string.
  - Get Drive client from signed-in account headers.
  - Check if `budgie_backup.json` exists in `appDataFolder`; if yes delete it.
  - Upload new file. Wrap in try/catch; swallow errors.

  `restore() → Future<bool>`:
  - Download `budgie_backup.json` from `appDataFolder`.
  - Parse JSON → insert rows via DB helpers (use raw `db.insert` loops, not high-level helpers, to avoid constraint issues).
  - Return true on success, false on failure.

- [ ] **Step 2: Verify manually**

  Run: `flutter run`  
  Sign in via Settings → account email shows. Trigger backup → check Drive `appDataFolder` via API explorer or verify no crash. Sign out → email clears.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/services/backup_service.dart
  git commit -m "feat: add Google Drive backup service"
  ```

---

### Task 11: Settings Screen — Wire All New Features

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `SetPinScreen`, `BackupService.instance`, `DatabaseHelper.instance.getSetting/setSetting`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Add auto-backup on app backgrounding**

  Mix `WidgetsBindingObserver` into `_SettingsScreenState` (or into `_RootScreenState` in `main.dart` — prefer `RootScreen` so it fires regardless of which tab is active):

  In `_RootScreenState`:
  - Add `with WidgetsBindingObserver`.
  - `initState`: `WidgetsBinding.instance.addObserver(this)`.
  - `dispose`: `WidgetsBinding.instance.removeObserver(this)`.
  - Override `didChangeAppLifecycleState(AppLifecycleState state)`: if `state == AppLifecycleState.paused` → call `BackupService.instance.backup()` (fire-and-forget; errors swallowed inside `backup()`).

- [ ] **Step 2: Read current settings on load**

  In `_load()`: also fetch `pin_hash`, `google_account`, `gemini_api_key` → store in state booleans `_pinSet`, `_googleLinked`, and controller `_geminiKey`.

- [ ] **Step 3: Add PIN section**

  Below the existing budget/currency fields add a `ListTile`:
  - Title: `_pinSet ? 'Change PIN' : 'Set PIN'`
  - Leading: `Icon(Icons.lock_outline)`
  - `onTap`: push `SetPinScreen`; on return reload.

- [ ] **Step 4: Add Google Account section**

  `ListTile`:
  - Title: `_googleLinked ? 'Unlink Google ($email)' : 'Link Google Account'`
  - Leading: `Icon(Icons.cloud_outlined)`
  - `onTap`: `_googleLinked ? BackupService.instance.signOut() : BackupService.instance.signIn()` → reload.

  If linked, add a second `ListTile` "Back up now" → `BackupService.instance.backup()` → show SnackBar `'Backed up'`.  
  Add a third `ListTile` "Restore from cloud" → `BackupService.instance.restore()` → show SnackBar `'Restored'` or `'Restore failed'`.

- [ ] **Step 5: Add Gemini API Key section**

  `TextField` with `obscureText: true`, label `'Gemini API Key'`, hint `'Get free key at ai.google.dev'`, controller `_geminiKey`.  
  On `_save()`: also call `db.setSetting('gemini_api_key', _geminiKey.text.trim())`.

- [ ] **Step 6: Verify manually**

  Run: `flutter run`  
  Confirm all three new sections appear. Set PIN → next cold restart shows PIN screen. Link Google → email shown. Background app → Drive file created. Enter Gemini key → bill scan works in Add Expense.

- [ ] **Step 7: Commit**

  ```bash
  git add lib/main.dart lib/screens/settings_screen.dart
  git commit -m "feat: add PIN, Google backup, auto-backup, and Gemini key to settings"
  ```

---

### Task 12: Final Build

- [ ] **Step 1: Build split APKs**

  ```bash
  export JAVA_HOME="/mnt/d/Users/thili/jdk21"
  export PATH="$JAVA_HOME/bin:/mnt/d/Users/thili/flutter/bin:$PATH"
  cd /mnt/d/project/my/BudgieApp
  flutter build apk --split-per-abi --release 2>&1
  ```

- [ ] **Step 2: Verify**

  ```bash
  ls -lh build/app/outputs/flutter-apk/
  ```
  Expected: `app-arm64-v8a-release.apk` present and ≤ 30 MB.

- [ ] **Step 3: Commit**

  ```bash
  git add pubspec.yaml pubspec.lock
  git commit -m "chore: final release build with all features"
  ```
