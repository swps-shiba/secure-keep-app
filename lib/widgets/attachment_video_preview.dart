export 'attachment_video_preview_stub.dart'
    if (dart.library.io) 'attachment_video_preview_native.dart'
    if (dart.library.js_interop) 'attachment_video_preview_web.dart';
