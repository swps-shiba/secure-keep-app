import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keep_app/models/memo.dart';
import 'package:secure_keep_app/services/encryption_service.dart';
import 'package:secure_keep_app/services/google_auth_service.dart';
import 'package:secure_keep_app/services/google_drive_service.dart';
import 'package:secure_keep_app/services/memo_cache_interface.dart';
import 'package:secure_keep_app/services/memo_storage_service.dart';

void main() {
  test('keeps local memo caches separate for each Google account', () async {
    final encryption = EncryptionService();
    encryption.unlockInMemoryFromRecoveryPhrase(
      'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about',
    );
    final drive = _AccountDriveService();
    final caches = <String, _MapMemoCache>{};
    final storage = MemoStorageService(
      encryptionService: encryption,
      driveService: drive,
      cacheFactory: (accountId) =>
          caches.putIfAbsent(accountId, _MapMemoCache.new),
    );
    final memo = Memo(
      id: 'memo-id',
      title: 'Personal memo',
      accountId: '',
      password: '',
      content: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await caches
        .putIfAbsent('personal@example.com', _MapMemoCache.new)
        .write(memo.id, encryption.encryptJson(memo.toJson()));

    drive.signedInAccount = 'personal@example.com';
    expect(
      (await storage.loadAll(syncFromDrive: false)).map((item) => item.title),
      ['Personal memo'],
    );

    drive.signedInAccount = 'work@swps.jp';
    expect(await storage.loadAll(syncFromDrive: false), isEmpty);
    expect(caches.keys, containsAll(['personal@example.com', 'work@swps.jp']));
  });

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

class _AccountDriveService extends GoogleDriveService {
  _AccountDriveService() : super(authService: GoogleAuthService());

  String signedInAccount = 'personal@example.com';

  @override
  Future<String> accountId() async => signedInAccount;
}

class _FailingDriveService extends GoogleDriveService {
  _FailingDriveService() : super(authService: GoogleAuthService());

  @override
  Future<List<DriveMemoFile>> listMemoFiles() async {
    throw StateError('Drive unavailable');
  }
}

class _MapMemoCache implements MemoCache {
  final Map<String, String> memos = {};

  @override
  Future<List<String>> listIds() async => memos.keys.toList();

  @override
  Future<String?> read(String id) async => memos[id];

  @override
  Future<void> write(String id, String ciphertext) async {
    memos[id] = ciphertext;
  }

  @override
  Future<Uint8List?> readAttachment(String id) async => null;

  @override
  Future<void> writeAttachment(String id, Uint8List ciphertext) async {}

  @override
  Future<void> deleteAttachment(String id) async {}

  @override
  Future<void> delete(String id) async {
    memos.remove(id);
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
