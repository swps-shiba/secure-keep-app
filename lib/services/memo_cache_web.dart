import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart' as idb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_keep_app/services/memo_cache_interface.dart';

MemoCache createMemoCache() => _WebMemoCache();

class _WebMemoCache implements MemoCache {
  static const _keyPrefix = 'secure_keep_encrypted_memo_';
  static const _attachmentStoreName = 'encrypted_attachments';
  static const _attachmentDatabaseName = 'secure_keep_encrypted_cache';
  static Future<idb.Database>? _database;

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<idb.Database> get _attachmentDatabase {
    return _database ??= _openAttachmentDatabase();
  }

  Future<idb.Database> _openAttachmentDatabase() async {
    final factory = idb.getIdbFactory();
    if (factory == null) {
      throw StateError('IndexedDB is not available in this browser');
    }
    return factory.open(
      _attachmentDatabaseName,
      version: 1,
      onUpgradeNeeded: (event) {
        event.database.createObjectStore(_attachmentStoreName);
      },
    );
  }

  @override
  Future<List<String>> listIds() async {
    final prefs = await _preferences;
    return prefs
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .map((key) => key.substring(_keyPrefix.length))
        .toList();
  }

  @override
  Future<String?> read(String id) async {
    final prefs = await _preferences;
    return prefs.getString('$_keyPrefix$id');
  }

  @override
  Future<void> write(String id, String ciphertext) async {
    final prefs = await _preferences;
    await prefs.setString('$_keyPrefix$id', ciphertext);
  }

  @override
  Future<void> delete(String id) async {
    final prefs = await _preferences;
    await prefs.remove('$_keyPrefix$id');
  }

  @override
  Future<Uint8List?> readAttachment(String id) async {
    final database = await _attachmentDatabase;
    final transaction = database.transaction(
      _attachmentStoreName,
      idb.idbModeReadOnly,
    );
    final value = await transaction
        .objectStore(_attachmentStoreName)
        .getObject(id);
    await transaction.completed;
    if (value == null) {
      return null;
    }
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    throw const FormatException('Invalid encrypted attachment cache entry');
  }

  @override
  Future<void> writeAttachment(String id, Uint8List ciphertext) async {
    final database = await _attachmentDatabase;
    final transaction = database.transaction(
      _attachmentStoreName,
      idb.idbModeReadWrite,
    );
    await transaction.objectStore(_attachmentStoreName).put(ciphertext, id);
    await transaction.completed;
  }

  @override
  Future<void> deleteAttachment(String id) async {
    final database = await _attachmentDatabase;
    final transaction = database.transaction(
      _attachmentStoreName,
      idb.idbModeReadWrite,
    );
    await transaction.objectStore(_attachmentStoreName).delete(id);
    await transaction.completed;
  }
}
