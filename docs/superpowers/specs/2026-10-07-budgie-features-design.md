# Budgie App — Feature Batch Design

**Date:** 2026-10-07  
**App:** Budgie — offline Flutter expense tracker (SQLite, teal theme, Android)  
**Current APK size:** 51.8 MB (fat APK)

---

## Scope

Five features in this batch. Items 1–3 are bounded changes. Items 4–5 are new subsystems.

---

## 1. Household Usage Update (bounded)

**Goal:** Allow users to record usage of a household item, reducing its quantity.

**Change:** `lib/screens/household_screen.dart`
- Each item tile gets a minus-circle icon button on the trailing edge (alongside the existing "low" chip).
- Tapping the icon opens a bottom sheet with:
  - Label: "How much did you use?"
  - Number input pre-filled with `1`, suffixed with the item's unit.
  - "Use" confirm button.
- On confirm: `quantity = max(0, quantity - used)` → `db.updateItem()` → list reloads.
- Tapping the tile itself still opens the full edit form (unchanged).

---

## 2. App Icon (bounded)

**Goal:** Replace the plain "B" icon with a recognisable budgie bird silhouette.

**Change:** Regenerate `assets/icon/app_icon.png` using a Python script.
- Design: teal rounded-square background, white budgie bird (oval body, round head, small beak, wing curve, tail feathers).
- Re-run `flutter_launcher_icons` to apply to all Android mipmap sizes.

---

## 3. Reduce App Size (bounded)

**Goal:** Reduce the download size users see on the Play Store.

**Change:** Build with `flutter build apk --split-per-abi`.
- Produces three APKs, one per CPU architecture.
- `app-arm64-v8a-release.apk` (~17–20 MB) — uploaded to Play Store; covers 95%+ of modern Android devices.
- No code changes required.

---

## 4. PIN Login + Google Drive Cloud Backup (architectural)

### 4.1 PIN Authentication

**Goal:** Protect the app's data behind a 4-digit PIN on every launch.

**First launch behaviour:**
- No PIN is stored → app opens directly to home (RootScreen).
- User sets a PIN via Settings → "Set PIN" option.

**Subsequent launches:**
- PIN is stored → `main.dart` routes to `PinScreen` before `RootScreen`.
- `PinScreen` shows 4 dot indicators + number pad.
- Correct PIN → navigate to `RootScreen`.
- Wrong PIN → shake animation + "Incorrect PIN" message.
- After 5 wrong attempts → "Forgot PIN?" button appears.

**Forgot PIN — Google linked:**
1. Re-authenticate with Google Sign-In.
2. Download backup JSON from Drive.
3. Wipe local SQLite DB.
4. Restore data from JSON.
5. Prompt user to set a new PIN.

**Forgot PIN — Google not linked:**
1. Show confirmation dialog: "This will delete all your data. Continue?"
2. On confirm: wipe SQLite DB → navigate to fresh home with no PIN set.

**PIN storage:** stored in the existing `settings` SQLite table under key `pin_hash`. The PIN is stored as a SHA-256 hash (not plaintext).

**New files:**
- `lib/screens/pin_screen.dart` — PIN entry UI and logic.
- `lib/screens/set_pin_screen.dart` — PIN setup/change UI (4-digit entry × 2 for confirmation).

**Modified files:**
- `lib/main.dart` — on startup, check `settings.pin_hash`; if present, route to `PinScreen` instead of `RootScreen`.
- `lib/screens/settings_screen.dart` — add "Set / Change PIN" and "Link Google Account" sections.
- `lib/db/database_helper.dart` — add `wipeAll()` method that drops and recreates all tables.

### 4.2 Google Drive Cloud Backup

**Goal:** Let users back up and restore their data via their own Google Drive (free, no cost to user).

**Backup behaviour:**
- Triggered automatically when the app goes to background (via `AppLifecycleState.paused`).
- Also available as "Back up now" button in Settings.
- Data serialised as JSON: all expenses, budgets, settings (excluding `pin_hash`), and household items.
- Written to the app's private Drive folder (`appDataFolder` scope — invisible to user in Drive UI, counts against their free quota but is very small).

**Restore behaviour:**
- Triggered during "Forgot PIN" flow when Google is linked (see above).
- Also available as "Restore from cloud" in Settings.

**Google Sign-In:**
- Settings screen shows "Link Google Account" button if not linked.
- On link: Google Sign-In OAuth flow → store account email in settings table under key `google_account`.
- On unlink: revoke token, remove key from settings.

**New files:**
- `lib/services/backup_service.dart` — handles Google Sign-In, serialisation, Drive upload/download.

**New packages:** `google_sign_in ^6.2.0`, `googleapis ^13.0.0`

**Failure handling:**
- If backup fails (no internet, Drive error): silently retry next time app backgrounds. No error shown to user unless they manually trigger it.
- If restore fails: show error dialog, keep existing local data intact.

---

## 5. Bill Scan + Gemini Auto-fill (architectural)

### 5.1 User API Key Setup

**Goal:** Use Gemini 1.5 Flash (free tier) to extract expense data from receipt photos. Each user provides their own free API key — no charges to user or developer.

**Setup flow:**
- Settings screen shows "Gemini API Key" field.
- User obtains free key from Google AI Studio (ai.google.dev).
- Key stored in `settings` table under key `gemini_api_key`.
- If key is not set: camera button on Add Expense screen is shown but tapping it shows a prompt: "Set your Gemini API key in Settings to use bill scanning."

### 5.2 Bill Scan Flow

1. User taps camera icon on `AddExpenseScreen` AppBar.
2. `image_picker` opens — user picks from gallery or takes photo.
3. Loading spinner shown on form.
4. Image sent to `GeminiService.extractFromReceipt(imageFile)`.
5. Gemini 1.5 Flash receives image + prompt asking for JSON with fields: `amount`, `date` (ISO8601), `category` (must match one of the app's 12 category names), `note` (merchant name or description).
6. Response parsed; form fields pre-filled with extracted values.
7. User reviews, corrects if needed, and saves normally.

**Error handling:**
- No internet: show snackbar "No connection. Enter manually."
- Gemini parse failure / unexpected response: show snackbar "Could not read bill. Please fill in manually." Form stays editable.
- Invalid API key: show snackbar "Invalid API key. Check Settings."

**New files:**
- `lib/services/gemini_service.dart` — image → Gemini API → parsed `ExpenseData` record.

**Modified files:**
- `lib/screens/add_expense_screen.dart` — add camera icon button, loading state, and `GeminiService` call.
- `lib/screens/settings_screen.dart` — add Gemini API Key input field.

**New packages:** `image_picker ^1.1.0`, `google_generative_ai ^0.4.0`

---

## Package Summary

| Package | Purpose | Size impact |
|---|---|---|
| `google_sign_in ^6.2.0` | Google OAuth for cloud backup | ~500 KB |
| `googleapis ^13.0.0` | Google Drive API | ~2 MB |
| `image_picker ^1.1.0` | Camera / gallery for bill scan | ~300 KB |
| `google_generative_ai ^0.4.0` | Gemini API client | ~500 KB |

**Expected ARM64 APK size after split:** ~18–21 MB

---

## Implementation Order

1. Bounded items first (#1 usage update, #2 icon, #3 size split) — no dependencies.
2. PIN login (#4.1) — foundation for app launch flow.
3. Google Drive backup (#4.2) — depends on PIN/settings work being in place.
4. Gemini bill scan (#5) — independent, can be done in parallel with #4.2.
