import 'dart:typed_data';

import 'package:secure_keep_app/services/memo_cache_factory.dart';
import 'package:secure_keep_app/services/memo_cache_interface.dart';
import 'package:secure_keep_app/models/memo.dart';
import 'package:secure_keep_app/services/encryption_service.dart';
import 'package:secure_keep_app/services/google_drive_service.dart';
import 'package:uuid/uuid.dart';

/// Hybrid storage: encrypt locally, sync ciphertext to Google Drive.
///
/// A local ciphertext cache speeds up offline reads. Plaintext is never written
/// to disk. Drive holds the durable copy for PC rescue / new-device recovery.
class MemoStorageService {
  MemoStorageService({
    required EncryptionService encryptionService,
    required GoogleDriveService driveService,
    Uuid? uuid,
    MemoCache? cache,
    MemoCache Function(String accountId)? cacheFactory,
  }) : _encryption = encryptionService,
       _drive = driveService,
       _uuid = uuid ?? const Uuid(),
       _providedCache = cache,
       _cacheFactory =
           cacheFactory ??
           ((accountId) => createMemoCache(namespace: accountId));

  final EncryptionService _encryption;
  final GoogleDriveService _drive;
  final Uuid _uuid;
  final MemoCache? _providedCache;
  final MemoCache Function(String accountId) _cacheFactory;
  final Map<String, MemoCache> _caches = {};

  Future<MemoCache> _cacheForCurrentAccount() async {
    final providedCache = _providedCache;
    if (providedCache != null) {
      return providedCache;
    }
    final accountId = await _drive.accountId();
    return _caches.putIfAbsent(accountId, () => _cacheFactory(accountId));
  }

  /// Pulls encrypted memos from Drive, decrypts in memory, refreshes cache.
  Future<List<Memo>> loadAll({bool syncFromDrive = true}) async {
    final cache = await _cacheForCurrentAccount();
    Object? syncError;
    if (syncFromDrive) {
      try {
        await _pullFromDrive(cache);
      } catch (error) {
        syncError = error;
      }
    }

    final memos = <Memo>[];
    for (final id in await cache.listIds()) {
      try {
        final payload = await cache.read(id);
        if (payload == null) {
          continue;
        }
        final json = _encryption.decryptJson(payload);
        memos.add(Memo.fromJson(json));
      } catch (_) {
        // Skip corrupted or undecryptable files.
      }
    }

    if (memos.isEmpty && syncError != null) {
      throw StateError(
        'Google Drive からメモを同期できませんでした。'
        'Google アカウントとリカバリーコードを確認してください。\n$syncError',
      );
    }

    memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return memos;
  }

  Future<void> _pullFromDrive(MemoCache cache) async {
    final remoteFiles = await _drive.listMemoFiles();
    final referencedAttachments = <String>{};

    for (final remote in remoteFiles) {
      final id = remote.name.replaceAll('.skm', '');
      final ciphertext = await _drive.downloadFile(remote.id);
      // Verify decryptable with current DEK before caching.
      final memo = Memo.fromJson(_encryption.decryptJson(ciphertext));
      referencedAttachments.addAll(
        memo.attachments.map((attachment) => '${memo.id}--${attachment.id}'),
      );
      await cache.write(id, ciphertext);
    }

    if (referencedAttachments.isEmpty) {
      return;
    }
    final remoteAttachments = await _drive.listAttachmentFiles();
    for (final remote in remoteAttachments) {
      final cacheId = remote.name.substring(
        0,
        remote.name.length - '.ska'.length,
      );
      if (!referencedAttachments.contains(cacheId)) {
        continue;
      }
      final ciphertext = await _drive.downloadBytes(remote.id);
      _encryption.decryptBytes(ciphertext);
      await cache.writeAttachment(cacheId, ciphertext);
    }
  }

  Future<Memo> create({
    required String title,
    required String accountId,
    required String password,
    required String content,
    int colorIndex = 0,
    List<MemoAttachment> attachments = const [],
    Map<String, Uint8List> newAttachments = const {},
  }) async {
    final now = DateTime.now();
    final memo = Memo(
      id: _uuid.v4(),
      title: title,
      accountId: accountId,
      password: password,
      content: content,
      createdAt: now,
      updatedAt: now,
      colorIndex: colorIndex,
      attachments: attachments,
    );
    await save(memo, newAttachments: newAttachments);
    return memo;
  }

  Future<void> save(
    Memo memo, {
    Map<String, Uint8List> newAttachments = const {},
  }) async {
    final cache = await _cacheForCurrentAccount();
    final oldPayload = await cache.read(memo.id);
    final oldAttachments = oldPayload == null
        ? const <MemoAttachment>[]
        : Memo.fromJson(_encryption.decryptJson(oldPayload)).attachments;
    final attachmentIds = memo.attachments
        .map((attachment) => attachment.id)
        .toSet();

    for (final entry in newAttachments.entries) {
      if (!attachmentIds.contains(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'newAttachments',
          'Attachment is not included in the memo',
        );
      }
      final ciphertext = _encryption.encryptBytes(entry.value);
      await cache.writeAttachment('${memo.id}--${entry.key}', ciphertext);
      await _drive.uploadAttachmentCiphertext(
        memoId: memo.id,
        attachmentId: entry.key,
        ciphertext: ciphertext,
      );
    }

    final ciphertext = _encryption.encryptJson(memo.toJson());
    await cache.write(memo.id, ciphertext);
    await _drive.uploadMemoCiphertext(memoId: memo.id, ciphertext: ciphertext);

    for (final oldAttachment in oldAttachments) {
      if (!attachmentIds.contains(oldAttachment.id)) {
        final cacheId = '${memo.id}--${oldAttachment.id}';
        await cache.deleteAttachment(cacheId);
        await _drive.deleteAttachmentFile(
          memoId: memo.id,
          attachmentId: oldAttachment.id,
        );
      }
    }
  }

  Future<Uint8List?> loadAttachment(String memoId, String attachmentId) async {
    final cache = await _cacheForCurrentAccount();
    final cacheId = '$memoId--$attachmentId';
    var ciphertext = await cache.readAttachment(cacheId);
    if (ciphertext == null) {
      final remoteFiles = await _drive.listAttachmentFiles();
      final remote = remoteFiles.where(
        (file) => file.name == '$memoId--$attachmentId.ska',
      );
      if (remote.isEmpty) {
        return null;
      }
      ciphertext = await _drive.downloadBytes(remote.first.id);
      _encryption.decryptBytes(ciphertext);
      await cache.writeAttachment(cacheId, ciphertext);
    }
    return _encryption.decryptBytes(ciphertext);
  }

  Future<void> delete(String id) async {
    final cache = await _cacheForCurrentAccount();
    final payload = await cache.read(id);
    if (payload != null) {
      final memo = Memo.fromJson(_encryption.decryptJson(payload));
      for (final attachment in memo.attachments) {
        final cacheId = '$id--${attachment.id}';
        await cache.deleteAttachment(cacheId);
        await _drive.deleteAttachmentFile(
          memoId: id,
          attachmentId: attachment.id,
        );
      }
    }
    await cache.delete(id);
    await _drive.deleteMemoFile(id);
  }
}
