import 'dart:typed_data';

abstract interface class MemoCache {
  Future<List<String>> listIds();

  Future<String?> read(String id);

  Future<void> write(String id, String ciphertext);

  Future<Uint8List?> readAttachment(String id);

  Future<void> writeAttachment(String id, Uint8List ciphertext);

  Future<void> deleteAttachment(String id);

  Future<void> delete(String id);
}
