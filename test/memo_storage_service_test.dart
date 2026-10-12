import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keep_app/services/encryption_service.dart';
import 'package:secure_keep_app/services/google_auth_service.dart';
import 'package:secure_keep_app/services/google_drive_service.dart';
import 'package:secure_keep_app/services/memo_cache_interface.dart';
import 'package:secure_keep_app/services/memo_storage_service.dart';

void main() {
  test(
    'reports Drive sync failure instead of showing an empty memo list',
    () async {
      final storage = MemoStorageService(
        encryptionService: EncryptionService(),
        driveService: _FailingDriveService(),
        cache: _EmptyMemoCache(),
      );

      await expectLater(
        storage.loadAll(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Google Drive からメモを同期できませんでした'),
          ),
        ),
      );
    },
  );
}

class _FailingDriveService extends GoogleDriveService {
  _FailingDriveService() : super(authService: GoogleAuthService());

  @override
  Future<List<DriveMemoFile>> listMemoFiles() async {
    throw StateError('Drive unavailable');
  }
}

class _EmptyMemoCache implements MemoCache {
  @override
  Future<List<String>> listIds() async => const [];

  @override
  Future<String?> read(String id) async => null;

  @override
  Future<void> write(String id, String ciphertext) async {}

  @override
  Future<Uint8List?> readAttachment(String id) async => null;

  @override
  Future<void> writeAttachment(String id, Uint8List ciphertext) async {}

  @override
  Future<void> deleteAttachment(String id) async {}

  @override
  Future<void> delete(String id) async {}
}
