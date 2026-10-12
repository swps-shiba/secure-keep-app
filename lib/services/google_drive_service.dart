import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:secure_keep_app/services/google_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uploads / downloads encrypted vault files under a dedicated Drive folder.
///
/// Folder name: [folderName]. Only ciphertext is stored — zero-knowledge.
class GoogleDriveService {
  GoogleDriveService({
    required GoogleAuthService authService,
    this.folderName = 'Secure Keep',
  }) : _auth = authService;

  static const _folderIdsPrefsKey = 'secure_keep_drive_folder_ids';
  static const _memoMime = 'application/octet-stream';
  static const _metaFileName = 'vault.meta.json';

  final GoogleAuthService _auth;
  final String folderName;

  final Map<String, String> _folderIds = {};

  Future<drive.DriveApi> _api() => _auth.driveApi();

  Future<String> accountId() async {
    await _auth.authenticatedClient();
    final accountId = _auth.currentUser?.id;
    if (accountId == null || accountId.isEmpty) {
      throw StateError('Signed-in Google account has no account identifier');
    }
    return accountId;
  }

  Future<String> ensureFolder() async {
    final account = await accountId();
    final cachedFolderId = _folderIds[account];
    if (cachedFolderId != null) {
      return cachedFolderId;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_folderIdsPrefsKey);
    final storedFolderIds = stored == null
        ? <String, dynamic>{}
        : jsonDecode(stored) as Map<String, dynamic>;
    final cached = storedFolderIds[account] as String?;
    if (cached != null && cached.isNotEmpty) {
      final api = await _api();
      try {
        final existing =
            await api.files.get(cached, $fields: 'id,trashed') as drive.File;
        if (existing.trashed != true) {
          _folderIds[account] = cached;
          return cached;
        }
      } catch (_) {
        // Cached id invalid — recreate below.
      }
    }

    final api = await _api();
    final listed = await api.files.list(
      q:
          "mimeType='application/vnd.google-apps.folder' "
          "and name='$folderName' and trashed=false "
          "and 'root' in parents",
      spaces: 'drive',
      $fields: 'files(id,name)',
      pageSize: 1,
    );

    String folderId;
    if (listed.files != null && listed.files!.isNotEmpty) {
      folderId = listed.files!.first.id!;
    } else {
      final created = await api.files.create(
        drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder',
      );
      folderId = created.id!;
    }

    _folderIds[account] = folderId;
    storedFolderIds[account] = folderId;
    await prefs.setString(_folderIdsPrefsKey, jsonEncode(storedFolderIds));
    return folderId;
  }

  Future<void> ensureVaultMeta() async {
    final folderId = await ensureFolder();
    final existing = await _findChild(folderId, _metaFileName);
    if (existing != null) {
      return;
    }

    final meta = jsonEncode({
      'version': 1,
      'app': 'secure_keep_app',
      'note': 'Ciphertext only. Recovery phrase required to decrypt. Zero-knowledge.',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    await _uploadBytes(
      fileName: _metaFileName,
      bytes: utf8.encode(meta),
      mimeType: 'application/json',
      existingFileId: null,
      parents: [folderId],
    );
  }

  Future<List<DriveMemoFile>> listMemoFiles() async {
    final folderId = await ensureFolder();
    final api = await _api();
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed=false and name contains '.skm'",
      spaces: 'drive',
      $fields: 'files(id,name,modifiedTime)',
      pageSize: 1000,
    );

    final files = result.files ?? const <drive.File>[];
    return files
        .where(
          (f) => f.id != null && f.name != null && f.name!.endsWith('.skm'),
        )
        .map(
          (f) => DriveMemoFile(
            id: f.id!,
            name: f.name!,
            modifiedTime: f.modifiedTime,
          ),
        )
        .toList();
  }

  Future<String> downloadFile(String fileId) async {
    return utf8.decode(await downloadBytes(fileId));
  }

  Future<Uint8List> downloadBytes(String fileId) async {
    final api = await _api();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  /// Creates or overwrites `{memoId}.skm` with encrypted payload.
  Future<void> uploadMemoCiphertext({
    required String memoId,
    required String ciphertext,
  }) async {
    final folderId = await ensureFolder();
    final fileName = '$memoId.skm';
    final existing = await _findChild(folderId, fileName);

    await _uploadBytes(
      fileName: fileName,
      bytes: utf8.encode(ciphertext),
      mimeType: _memoMime,
      existingFileId: existing?.id,
      parents: [folderId],
    );
  }

  Future<void> deleteMemoFile(String memoId) async {
    final folderId = await ensureFolder();
    final existing = await _findChild(folderId, '$memoId.skm');
    if (existing?.id == null) {
      return;
    }
    final api = await _api();
    await api.files.delete(existing!.id!);
  }

  Future<List<DriveMemoFile>> listAttachmentFiles() async {
    final folderId = await ensureFolder();
    final api = await _api();
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed=false and name contains '.ska'",
      spaces: 'drive',
      $fields: 'files(id,name,modifiedTime)',
      pageSize: 1000,
    );

    return (result.files ?? const <drive.File>[])
        .where(
          (f) => f.id != null && f.name != null && f.name!.endsWith('.ska'),
        )
        .map(
          (f) => DriveMemoFile(
            id: f.id!,
            name: f.name!,
            modifiedTime: f.modifiedTime,
          ),
        )
        .toList();
  }

  Future<void> uploadAttachmentCiphertext({
    required String memoId,
    required String attachmentId,
    required Uint8List ciphertext,
  }) async {
    final folderId = await ensureFolder();
    final fileName = '$memoId--$attachmentId.ska';
    final existing = await _findChild(folderId, fileName);
    await _uploadBytes(
      fileName: fileName,
      bytes: ciphertext,
      mimeType: _memoMime,
      existingFileId: existing?.id,
      parents: [folderId],
      uploadOptions: drive.UploadOptions.resumable,
    );
  }

  Future<void> deleteAttachmentFile({
    required String memoId,
    required String attachmentId,
  }) async {
    final folderId = await ensureFolder();
    final existing = await _findChild(folderId, '$memoId--$attachmentId.ska');
    if (existing?.id == null) {
      return;
    }
    final api = await _api();
    await api.files.delete(existing!.id!);
  }

  Future<drive.File?> _findChild(String folderId, String name) async {
    final api = await _api();
    final escaped = name.replaceAll("'", "\\'");
    final listed = await api.files.list(
      q: "'$folderId' in parents and name='$escaped' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    if (listed.files == null || listed.files!.isEmpty) {
      return null;
    }
    return listed.files!.first;
  }

  Future<void> _uploadBytes({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String? existingFileId,
    required List<String> parents,
    drive.UploadOptions uploadOptions = drive.UploadOptions.defaultOptions,
  }) async {
    final api = await _api();
    final media = drive.Media(
      Stream<List<int>>.fromIterable([bytes]),
      bytes.length,
      contentType: mimeType,
    );

    if (existingFileId != null) {
      await api.files.update(
        drive.File()..name = fileName,
        existingFileId,
        uploadOptions: uploadOptions,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File()
          ..name = fileName
          ..parents = parents
          ..mimeType = mimeType,
        uploadOptions: uploadOptions,
        uploadMedia: media,
      );
    }
  }
}

class DriveMemoFile {
  const DriveMemoFile({
    required this.id,
    required this.name,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final DateTime? modifiedTime;
}
