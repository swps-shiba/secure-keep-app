import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:secure_keep_app/models/memo.dart';
import 'package:secure_keep_app/services/memo_storage_service.dart';
import 'package:secure_keep_app/theme/app_theme.dart';
import 'package:secure_keep_app/widgets/attachment_video_preview.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';

class MemoEditScreen extends StatefulWidget {
  const MemoEditScreen({super.key, required this.storage, this.memo});

  final MemoStorageService storage;
  final Memo? memo;

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _accountIdController;
  late final TextEditingController _passwordController;
  late final TextEditingController _contentController;
  late int _colorIndex;
  final List<MemoAttachment> _attachments = [];
  final Map<String, Uint8List> _pendingAttachmentBytes = {};
  final Map<String, Future<Uint8List?>> _attachmentLoads = {};
  final Uuid _uuid = const Uuid();
  bool _obscurePassword = true;
  bool _saving = false;
  bool _waitingForPaste = false;

  bool get _isEditing => widget.memo != null;

  @override
  void initState() {
    super.initState();
    final memo = widget.memo;
    _titleController = TextEditingController(text: memo?.title ?? '');
    _accountIdController = TextEditingController(text: memo?.accountId ?? '');
    _passwordController = TextEditingController(text: memo?.password ?? '');
    _contentController = TextEditingController(text: memo?.content ?? '');
    _colorIndex = memo?.colorIndex ?? 0;
    _attachments.addAll(memo?.attachments ?? const []);
    ClipboardEvents.instance?.registerPasteEventListener(_onWebPaste);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _accountIdController.dispose();
    _passwordController.dispose();
    _contentController.dispose();
    ClipboardEvents.instance?.unregisterPasteEventListener(_onWebPaste);
    super.dispose();
  }

  static const _clipboardFormats = <(FileFormat, String)>[
    (Formats.png, 'image/png'),
    (Formats.jpeg, 'image/jpeg'),
    (Formats.gif, 'image/gif'),
    (Formats.webp, 'image/webp'),
    (Formats.heic, 'image/heic'),
    (Formats.heif, 'image/heif'),
    (Formats.mp4, 'video/mp4'),
    (Formats.mov, 'video/quicktime'),
    (Formats.m4v, 'video/x-m4v'),
    (Formats.avi, 'video/x-msvideo'),
    (Formats.mpeg, 'video/mpeg'),
    (Formats.webm, 'video/webm'),
    (Formats.ogg, 'video/ogg'),
    (Formats.wmv, 'video/x-ms-wmv'),
    (Formats.flv, 'video/x-flv'),
    (Formats.mkv, 'video/x-matroska'),
    (Formats.ts, 'video/vnd.dlna.mpeg-tts'),
  ];

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.media,
        allowMultiple: true,
        withData: true,
      );
      if (result == null) {
        return;
      }
      for (final file in result.files) {
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        _addAttachment(
          name: file.name,
          mimeType: _mimeTypeFromName(file.name),
          bytes: bytes,
        );
      }
    } catch (error) {
      _showMessage('ファイルを追加できませんでした: $error');
    }
  }

  Future<void> _pasteFromClipboard() async {
    if (kIsWeb) {
      setState(() => _waitingForPaste = true);
      _showMessage('写真または動画をコピーして、Ctrl+V / ⌘V を押してください');
      return;
    }
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        _showMessage('この端末ではクリップボードを利用できません');
        return;
      }
      await _addClipboardItems(await clipboard.read());
    } catch (error) {
      _showMessage('クリップボードから追加できませんでした: $error');
    }
  }

  void _onWebPaste(ClipboardReadEvent event) {
    if (!_waitingForPaste) {
      return;
    }
    setState(() => _waitingForPaste = false);
    unawaited(
      event.getClipboardReader().then(_addClipboardItems).catchError((
        Object error,
      ) {
        _showMessage('クリップボードから追加できませんでした: $error');
      }),
    );
  }

  Future<void> _addClipboardItems(ClipboardReader reader) async {
    var added = 0;
    for (final item in reader.items) {
      for (final (format, mimeType) in _clipboardFormats) {
        if (!item.canProvide(format)) {
          continue;
        }
        final completer = Completer<DataReaderFile>();
        final progress = item.getFile(
          format,
          (file) => completer.complete(file),
          onError: (error) => completer.completeError(error),
        );
        if (progress == null) {
          continue;
        }
        final file = await completer.future;
        final bytes = await file.readAll();
        _addAttachment(
          name: file.fileName ?? 'clipboard.${_extensionForMime(mimeType)}',
          mimeType: mimeType,
          bytes: bytes,
        );
        added++;
        break;
      }
    }
    if (added == 0) {
      _showMessage('クリップボードに写真または動画がありません');
    }
  }

  void _addAttachment({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    if (!mounted) {
      return;
    }
    if (!mimeType.startsWith('image/') && !mimeType.startsWith('video/')) {
      _showMessage('写真または動画ファイルを選択してください');
      return;
    }
    if (bytes.isEmpty) {
      _showMessage('空のファイルは追加できません');
      return;
    }
    final attachment = MemoAttachment(
      id: _uuid.v4(),
      name: name,
      mimeType: mimeType,
    );
    setState(() {
      _attachments.add(attachment);
      _pendingAttachmentBytes[attachment.id] = bytes;
    });
  }

  Future<Uint8List?> _loadAttachment(MemoAttachment attachment) {
    return _attachmentBytes(attachment);
  }

  Future<Uint8List?> _attachmentBytes(MemoAttachment attachment) {
    final pending = _pendingAttachmentBytes[attachment.id];
    return _attachmentLoads.putIfAbsent(
      attachment.id,
      () => pending != null
          ? Future.value(pending)
          : widget.storage.loadAttachment(widget.memo!.id, attachment.id),
    );
  }

  Future<void> _previewAttachment(MemoAttachment attachment) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: 560,
          child: FutureBuilder<Uint8List?>(
            future: _attachmentBytes(attachment),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('添付ファイルを読み込めませんでした: ${snapshot.error}');
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return const Text('添付ファイルが見つかりません。同期後にもう一度お試しください。');
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 440),
                child: attachment.isImage
                    ? InteractiveViewer(
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Text('この画像形式はプレビューできません')),
                        ),
                      )
                    : SizedBox(
                        height: 380,
                        child: buildAttachmentVideoPreview(
                          bytes,
                          attachment.mimeType,
                        ),
                      ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
          FutureBuilder<Uint8List?>(
            future: _attachmentBytes(attachment),
            builder: (context, snapshot) => TextButton.icon(
              onPressed: snapshot.data == null
                  ? null
                  : () => _downloadAttachment(attachment, snapshot.data!),
              icon: const Icon(Icons.download_outlined),
              label: const Text('ダウンロード'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAttachment(
    MemoAttachment attachment,
    Uint8List bytes,
  ) async {
    try {
      final path = await FilePicker.saveFile(
        fileName: attachment.name,
        bytes: bytes,
      );
      if (kIsWeb) {
        _showMessage('復号したファイルのダウンロードを開始しました');
      } else if (path != null) {
        _showMessage('復号したファイルを保存しました');
      }
    } catch (error) {
      _showMessage('ダウンロードに失敗しました: $error');
    }
  }

  void _removeAttachment(MemoAttachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.id == attachment.id);
      _pendingAttachmentBytes.remove(attachment.id);
      _attachmentLoads.remove(attachment.id);
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _mimeTypeFromName(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'avi' => 'video/x-msvideo',
      'mpeg' || 'mpg' => 'video/mpeg',
      'webm' => 'video/webm',
      'ogg' => 'video/ogg',
      'wmv' => 'video/x-ms-wmv',
      'flv' => 'video/x-flv',
      'mkv' => 'video/x-matroska',
      'ts' => 'video/vnd.dlna.mpeg-tts',
      _ => 'application/octet-stream',
    };
  }

  String _extensionForMime(String mimeType) {
    return switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'video/quicktime' => 'mov',
      'video/x-msvideo' => 'avi',
      'video/x-m4v' => 'm4v',
      'video/webm' => 'webm',
      'video/ogg' => 'ogg',
      _ => mimeType.split('/').last,
    };
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        final updated = widget.memo!.copyWith(
          title: title,
          accountId: _accountIdController.text.trim(),
          password: _passwordController.text,
          content: _contentController.text,
          colorIndex: _colorIndex,
          attachments: List.unmodifiable(_attachments),
          updatedAt: DateTime.now(),
        );
        await widget.storage.save(
          updated,
          newAttachments: _pendingAttachmentBytes,
        );
      } else {
        await widget.storage.create(
          title: title,
          accountId: _accountIdController.text.trim(),
          password: _passwordController.text,
          content: _contentController.text,
          colorIndex: _colorIndex,
          attachments: List.unmodifiable(_attachments),
          newAttachments: _pendingAttachmentBytes,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final memo = widget.memo;
    if (memo == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを削除'),
        content: const Text('この暗号化メモを削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.storage.delete(memo.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bg = MemoColors.forIndex(_colorIndex);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: '削除',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'タイトル',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _accountIdController,
            decoration: const InputDecoration(
              labelText: 'ID',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'パスワード',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            minLines: 8,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'メモ内容',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 120),
                child: Icon(Icons.notes_outlined),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '写真・動画',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'クリップボードから貼り付け',
                onPressed: _saving ? null : _pasteFromClipboard,
                icon: const Icon(Icons.content_paste),
              ),
              IconButton(
                tooltip: '写真・動画を選択',
                onPressed: _saving ? null : _pickAttachments,
                icon: const Icon(Icons.attach_file),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final attachment in _attachments)
              _buildAttachmentTile(attachment),
          ],
          const SizedBox(height: 20),
          Text('カラー', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(MemoColors.noteColors.length, (index) {
              final selected = index == _colorIndex;
              return GestureDetector(
                onTap: () => setState(() => _colorIndex = index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MemoColors.noteColors[index],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black26,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: selected ? const Icon(Icons.check, size: 18) : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(MemoAttachment attachment) {
    final bytes = _pendingAttachmentBytes[attachment.id];
    final image = bytes != null
        ? Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image_outlined),
          )
        : FutureBuilder<Uint8List?>(
            future: _loadAttachment(attachment),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Icon(Icons.broken_image_outlined);
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snapshot.data == null) {
                return const Icon(Icons.broken_image_outlined);
              }
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image_outlined),
              );
            },
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: attachment.isImage
                  ? image
                  : const Icon(Icons.video_file_outlined, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'プレビュー・ダウンロード',
              onPressed: () => _previewAttachment(attachment),
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: '添付を削除',
              onPressed: _saving ? null : () => _removeAttachment(attachment),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
