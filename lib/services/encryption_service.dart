import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secure_keep_app/services/recovery_phrase_service.dart';

/// AES-256-CBC encryption. The DEK is derived from the 12-word recovery phrase
/// and optionally cached in Keystore / Keychain after biometric unlock.
///
/// Drive only ever stores ciphertext — never the phrase or DEK.
class EncryptionService {
  EncryptionService({
    FlutterSecureStorage? secureStorage,
    RecoveryPhraseService? recoveryPhraseService,
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _recovery = recoveryPhraseService ?? RecoveryPhraseService();

  static const _masterKeyStorageKey = 'secure_keep_aes256_master_key';
  static const _vaultReadyKey = 'secure_keep_vault_ready';

  final FlutterSecureStorage _secureStorage;
  final RecoveryPhraseService _recovery;
  enc.Key? _cachedKey;

  bool get isUnlocked => _cachedKey != null;

  Future<bool> hasStoredMasterKey() async {
    final ready = await _secureStorage.read(key: _vaultReadyKey);
    final key = await _secureStorage.read(key: _masterKeyStorageKey);
    return ready == '1' && key != null && key.isNotEmpty;
  }

  /// Unlocks using the DEK previously cached on this device.
  Future<void> unlockFromSecureStorage() async {
    final existing = await _secureStorage.read(key: _masterKeyStorageKey);
    if (existing == null || existing.isEmpty) {
      throw StateError('No master key cached on this device');
    }
    _cachedKey = enc.Key.fromBase64(existing);
  }

  /// Derives the DEK from the recovery phrase (in-memory only).
  void unlockInMemoryFromRecoveryPhrase(String mnemonic) {
    _cachedKey = _recovery.deriveMasterKey(mnemonic);
  }

  /// Derives the DEK from the recovery phrase and caches it on-device.
  Future<void> unlockFromRecoveryPhrase(String mnemonic) async {
    unlockInMemoryFromRecoveryPhrase(mnemonic);
    await _secureStorage.write(
      key: _masterKeyStorageKey,
      value: _cachedKey!.base64,
    );
    await _secureStorage.write(key: _vaultReadyKey, value: '1');
  }

  /// First-time setup: generate phrase, derive DEK, cache locally.
  Future<String> createVault() async {
    final mnemonic = _recovery.generateMnemonic();
    await unlockFromRecoveryPhrase(mnemonic);
    return mnemonic;
  }

  void lock() {
    _cachedKey = null;
  }

  Future<void> clearVault() async {
    _cachedKey = null;
    await _secureStorage.delete(key: _masterKeyStorageKey);
    await _secureStorage.delete(key: _vaultReadyKey);
  }

  enc.Key _requireKey() {
    final key = _cachedKey;
    if (key == null) {
      throw StateError('Vault is locked');
    }
    return key;
  }

  /// Encrypts [plainText] with AES-256-CBC. Returns `iv:ciphertext` (Base64).
  String encrypt(String plainText) {
    final key = _requireKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Uint8List encryptBytes(List<int> plainBytes) {
    final key = _requireKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  Uint8List decryptBytes(List<int> payload) {
    if (payload.length < 32 || payload.length % 16 != 0) {
      throw const FormatException('Invalid encrypted attachment format');
    }

    final key = _requireKey();
    final iv = enc.IV(Uint8List.fromList(payload.sublist(0, 16)));
    final encrypted = enc.Encrypted(Uint8List.fromList(payload.sublist(16)));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  String decrypt(String payload) {
    final parts = payload.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted payload format');
    }

    final key = _requireKey();
    final iv = enc.IV.fromBase64(parts[0]);
    final encrypted = enc.Encrypted.fromBase64(parts[1]);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  String encryptJson(Map<String, dynamic> json) {
    return encrypt(jsonEncode(json));
  }

  Map<String, dynamic> decryptJson(String payload) {
    final plain = decrypt(payload);
    final decoded = jsonDecode(plain);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Decrypted payload is not a JSON object');
    }
    return decoded;
  }

  bool validateMnemonic(String mnemonic) => _recovery.isValidMnemonic(mnemonic);
}
