import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Receipt photos are copied into the app's documents folder and stored by
/// file name only, because the full path changes when iOS updates the app.
class ReceiptPhotos {
  ReceiptPhotos._();
  static final ReceiptPhotos instance = ReceiptPhotos._();

  @visibleForTesting
  Directory? directoryOverride;

  Future<Directory> _folder() async {
    final folder = directoryOverride ??
        Directory(p.join(
            (await getApplicationDocumentsDirectory()).path, 'receipts'));
    await folder.create(recursive: true);
    return folder;
  }

  // Names come from the database or a backup, so never follow a path in one.
  Future<File> _fileFor(String name) async =>
      File(p.join((await _folder()).path, p.basename(name)));

  /// Copies [source] into the receipts folder and returns its new name.
  Future<String> save(File source) async {
    final ext = p.extension(source.path).toLowerCase();
    final name = 'receipt_${DateTime.now().microsecondsSinceEpoch}'
        '${ext.isEmpty ? '.jpg' : ext}';
    await source.copy((await _fileFor(name)).path);
    return name;
  }

  /// The photo's file, or null when it is missing, such as after restoring
  /// a backup on another phone.
  Future<File?> find(String? name) async {
    if (name == null) return null;
    try {
      final file = await _fileFor(name);
      return await file.exists() ? file : null;
    } catch (e) {
      debugPrint('ReceiptPhotos.find: $e');
      return null;
    }
  }

  Future<void> delete(String? name) async {
    if (name == null) return;
    try {
      final file = await _fileFor(name);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('ReceiptPhotos.delete: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      final folder = await _folder();
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (e) {
      debugPrint('ReceiptPhotos.deleteAll: $e');
    }
  }
}
