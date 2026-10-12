import 'package:secure_keep_app/services/memo_cache_interface.dart';
import 'package:secure_keep_app/services/memo_cache_stub.dart'
    if (dart.library.io) 'package:secure_keep_app/services/memo_cache_io.dart'
    if (dart.library.js_interop) 'package:secure_keep_app/services/memo_cache_web.dart'
    as platform;

MemoCache createMemoCache({required String namespace}) =>
    platform.createMemoCache(namespace: namespace);
