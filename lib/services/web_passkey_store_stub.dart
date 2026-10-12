class WebPasskeyStore {
  bool get hasKey => false;

  Future<void> protectKey(
    String base64Key, {
    bool replaceExisting = false,
  }) async {
    throw UnsupportedError('Passkeys are only available on Web');
  }

  Future<String> unlockKey() async {
    throw UnsupportedError('Passkeys are only available on Web');
  }

  void clear() {}
}
