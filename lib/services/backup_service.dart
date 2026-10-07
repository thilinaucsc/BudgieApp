import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> signIn() async {
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
    final email = await DatabaseHelper.instance.getSetting('google_account', '');
    return email.isEmpty ? null : email;
  }

  // ── Drive client ──────────────────────────────────────────────────────────

  Future<drive.DriveApi?> _driveApi() async {
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

  Future<void> restoreData() async {
    final data = _pendingRestore;
    if (data == null) return;
    final db = DatabaseHelper.instance;
    final raw = await db.database;

    for (final row in (data['expenses'] as List? ?? [])) {
      await raw.insert('expenses', Map<String, dynamic>.from(row as Map),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final row in (data['budgets'] as List? ?? [])) {
      await raw.insert('budgets', Map<String, dynamic>.from(row as Map),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final row in (data['household_items'] as List? ?? [])) {
      await raw.insert('household_items', Map<String, dynamic>.from(row as Map),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final row in (data['settings'] as List? ?? [])) {
      await raw.insert('settings', Map<String, dynamic>.from(row as Map),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    // Only clear pending data after all inserts succeed; if an insert throws,
    // the caller can retry by calling restoreData() again.
    _pendingRestore = null;
  }

  // ── Serialise ─────────────────────────────────────────────────────────────

  Future<String> _serialize() async {
    final db = DatabaseHelper.instance;
    final raw = await db.database;
    final expenses = await raw.query('expenses');
    final budgets = await raw.query('budgets');
    final items = await raw.query('household_items');
    final settings = (await raw.query('settings'))
        .where((r) => r['key'] != 'pin_hash')
        .toList();
    return jsonEncode({
      'expenses': expenses,
      'budgets': budgets,
      'household_items': items,
      'settings': settings,
    });
  }
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
