import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Google Sign-In needs an iOS client ID in Info.plist, which this app
  /// does not have yet, so cloud backup is Android only for now.
  static bool get isSupported => !Platform.isIOS;

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> signIn() async {
    if (!isSupported) return false;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      await DatabaseHelper.instance.setSetting('google_account', account.email);
      return true;
    } catch (e) {
      debugPrint('BackupService.signIn: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await DatabaseHelper.instance.setSetting('google_account', '');
  }

  Future<String?> accountEmail() async {
    final email = await DatabaseHelper.instance.getSetting(
      'google_account',
      '',
    );
    return email.isEmpty ? null : email;
  }

  // ── Drive client ──────────────────────────────────────────────────────────

  Future<drive.DriveApi?> _driveApi() async {
    if (!isSupported) return null;
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) return null;
      final headers = await account.authHeaders;
      return drive.DriveApi(_AuthClient(headers));
    } catch (e) {
      debugPrint('BackupService._driveApi: $e');
      return null;
    }
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  Future<void> backup() async {
    try {
      // Without a linked account there is nothing to back up to. Skipping
      // here also avoids touching Google Sign-In where it isn't configured.
      if (await accountEmail() == null) return;
      final api = await _driveApi();
      if (api == null) return;
      final json = await _serialize();
      final bytes = utf8.encode(json);

      final existing = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = 'budgie_backup.json'",
        $fields: 'files(id)',
      );
      for (final f in existing.files ?? []) {
        await api.files.delete(f.id!);
      }

      final meta = drive.File()
        ..name = 'budgie_backup.json'
        ..parents = ['appDataFolder'];
      await api.files.create(
        meta,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    } catch (e) {
      debugPrint('BackupService.backup: $e');
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  Map<String, dynamic>? _pendingRestore;

  Future<bool> restore() async {
    try {
      final api = await _driveApi();
      if (api == null) return false;
      final list = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = 'budgie_backup.json'",
        $fields: 'files(id)',
      );
      if (list.files == null || list.files!.isEmpty) return false;
      final fileId = list.files!.first.id!;
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final chunks = <int>[];
      await for (final chunk in media.stream) {
        chunks.addAll(chunk);
      }
      _pendingRestore = jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
      return true;
    } catch (e) {
      debugPrint('BackupService.restore: $e');
      return false;
    }
  }

  /// Replaces local data with the downloaded backup. Runs in one transaction,
  /// so a failed restore leaves the existing data untouched.
  Future<void> restoreData() async {
    final data = _pendingRestore;
    if (data == null) return;
    final db = DatabaseHelper.instance;
    final raw = await db.database;

    await raw.transaction((txn) async {
      for (final table in _tables) {
        // Older backups lack newer tables, so keep what is on this phone.
        if (!data.containsKey(table)) continue;
        await txn.delete(table);
        for (final row in (data[table] as List? ?? [])) {
          await txn.insert(
            table,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
    await db.loadCustomCategories();
    // Only clear pending data after all inserts succeed; if an insert throws,
    // the caller can retry by calling restoreData() again.
    _pendingRestore = null;
  }

  // ── Serialise ─────────────────────────────────────────────────────────────

  static const _tables = [
    'expenses',
    'budgets',
    'household_items',
    'recurring_expenses',
    'category_budgets',
    'splitter_trips',
    'splitter_participants',
    'splitter_expenses',
    'splitter_expense_shares',
    'income',
    'savings_goals',
    'savings_contributions',
    'custom_categories',
    'debts',
    'debt_payments',
    'accounts',
    'account_transfers',
    'favourites',
    'settings',
  ];

  Future<String> _serialize() async {
    final raw = await DatabaseHelper.instance.database;
    final backup = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      final rows = await raw.query(table);
      backup[table] = table == 'settings'
          ? rows.where((r) => r['key'] != 'pin_hash').toList()
          : rows;
    }
    return jsonEncode(backup);
  }

  @visibleForTesting
  Future<String> serializeForTest() => _serialize();

  @visibleForTesting
  void setPendingRestoreForTest(String json) =>
      _pendingRestore = jsonDecode(json) as Map<String, dynamic>;
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _inner = http.Client();
  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
