import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

Widget buildAttachmentVideoPreview(Uint8List bytes, String mimeType) {
  return _NativeVideoPreview(bytes: bytes, mimeType: mimeType);
}

class _NativeVideoPreview extends StatefulWidget {
  const _NativeVideoPreview({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  @override
  State<_NativeVideoPreview> createState() => _NativeVideoPreviewState();
}

class _NativeVideoPreviewState extends State<_NativeVideoPreview> {
  VideoPlayerController? _controller;
  File? _temporaryFile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final directory = await getTemporaryDirectory();
      if (!mounted) {
        return;
      }
      final extension = switch (widget.mimeType) {
        'video/quicktime' => 'mov',
        'video/x-m4v' => 'm4v',
        'video/x-msvideo' => 'avi',
        'video/vnd.dlna.mpeg-tts' => 'ts',
        _ =>
          widget.mimeType
              .split('/')
              .last
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
      };
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'secure_keep_preview_${const Uuid().v4()}.$extension',
      );
      _temporaryFile = file;
      await file.writeAsBytes(widget.bytes, flush: true);
      if (!mounted) {
        await file.delete();
        _temporaryFile = null;
        return;
      }
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        _controller = null;
        await file.delete();
        _temporaryFile = null;
        return;
      }
      setState(() {});
    } catch (error) {
      final controller = _controller;
      _controller = null;
      await controller?.dispose();
      final file = _temporaryFile;
      _temporaryFile = null;
      if (file != null && await file.exists()) {
        await file.delete();
      }
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    unawaited(_disposePreview());
    super.dispose();
  }

  Future<void> _disposePreview() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
    final file = _temporaryFile;
    _temporaryFile = null;
    if (file != null) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return Center(child: Text('動画を再生できませんでした: $_error'));
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        IconButton(
          tooltip: controller.value.isPlaying ? '一時停止' : '再生',
          onPressed: () {
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
      ],
    );
  }
}
