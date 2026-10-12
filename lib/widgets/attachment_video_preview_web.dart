import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildAttachmentVideoPreview(Uint8List bytes, String mimeType) {
  return _WebVideoPreview(bytes: bytes, mimeType: mimeType);
}

class _WebVideoPreview extends StatefulWidget {
  const _WebVideoPreview({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  @override
  State<_WebVideoPreview> createState() => _WebVideoPreviewState();
}

class _WebVideoPreviewState extends State<_WebVideoPreview> {
  late final String _viewType;
  late final String _objectUrl;
  late final web.HTMLVideoElement _video;

  @override
  void initState() {
    super.initState();
    _viewType = 'secure-keep-video-${identityHashCode(this)}';
    final blob = web.Blob(
      [widget.bytes.toJS].toJS,
      web.BlobPropertyBag(type: widget.mimeType),
    );
    _objectUrl = web.URL.createObjectURL(blob);
    _video = web.HTMLVideoElement()
      ..src = _objectUrl
      ..controls = true
      ..preload = 'metadata'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
  }

  @override
  void dispose() {
    _video.pause();
    _video.removeAttribute('src');
    _video.load();
    web.URL.revokeObjectURL(_objectUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
