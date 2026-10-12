import 'dart:typed_data';

import 'package:secure_keep_app/services/memo_cache_interface.dart';

MemoCache createMemoCache({required String namespace}) =>
    _UnsupportedMemoCache();

class _UnsupportedMemoCache implements MemoCache {
  Never _unsupported() =>
      throw UnsupportedError('Memo cache is not supported on this platform');

  @override
  Future<void> delete(String id) async => _unsupported();

  @override
  Future<Uint8List?> readAttachment(String id) async => _unsupported();

  @override
  Future<void> writeAttachment(String id, Uint8List ciphertext) async =>
      _unsupported();

  @override
  Future<void> deleteAttachment(String id) async => _unsupported();

  @override
  Future<List<String>> listIds() async => _unsupported();

  @override
  Future<String?> read(String id) async => _unsupported();

  @override
  Future<void> write(String id, String ciphertext) async => _unsupported();
}
