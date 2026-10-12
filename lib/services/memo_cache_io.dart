import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:secure_keep_app/services/memo_cache_interface.dart';

MemoCache createMemoCache({required String namespace}) =>
    _IoMemoCache(namespace);

class _IoMemoCache implements MemoCache {
  static const _cacheDirName = 'encrypted_memos_cache';

  _IoMemoCache(String namespace)
    : _namespace = base64Url.encode(utf8.encode(namespace));

  final String _namespace;

  Future<Directory> _cacheDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/$_cacheDirName/$_namespace');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<List<String>> listIds() async {
    final dir = await _cacheDirectory();
    return dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.skm'))
        .map(
          (file) => file.uri.pathSegments.last.substring(
            0,
            file.uri.pathSegments.last.length - '.skm'.length,
          ),
        )
        .toList();
  }

  @override
  Future<String?> read(String id) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/$id.skm');
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String id, String ciphertext) async {
    final dir = await _cacheDirectory();
    await File('${dir.path}/$id.skm').writeAsString(ciphertext, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/$id.skm');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Uint8List?> readAttachment(String id) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/$id.ska');
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> writeAttachment(String id, Uint8List ciphertext) async {
    final dir = await _cacheDirectory();
    await File('${dir.path}/$id.ska').writeAsBytes(ciphertext, flush: true);
  }

  @override
  Future<void> deleteAttachment(String id) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/$id.ska');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
