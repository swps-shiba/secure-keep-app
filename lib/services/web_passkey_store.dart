import 'dart:js_interop';

@JS('secureKeepPasskeyHasKey')
external JSBoolean _hasKey();

@JS('secureKeepPasskeyProtectKey')
external JSPromise<JSBoolean> _protectKey(JSString key, JSBoolean replaceExisting);

@JS('secureKeepPasskeyUnlockKey')
external JSPromise<JSString> _unlockKey();

@JS('secureKeepPasskeyClear')
external void _clear();

class WebPasskeyStore {
  bool get hasKey => _hasKey().toDart;

  Future<void> protectKey(
    String base64Key, {
    bool replaceExisting = false,
  }) async {
    final protected = await _protectKey(
      base64Key.toJS,
      replaceExisting.toJS,
    ).toDart;
    if (!protected.toDart) {
      throw StateError('Passkey key protection was not completed');
    }
  }

  Future<String> unlockKey() async => (await _unlockKey().toDart).toDart;

  void clear() => _clear();
}
