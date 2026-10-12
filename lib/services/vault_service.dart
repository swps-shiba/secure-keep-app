import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:secure_keep_app/services/encryption_service.dart';
import 'package:secure_keep_app/services/google_auth_service.dart';
import 'package:secure_keep_app/services/google_drive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VaultPhase { needsSetup, needsUnlock, unlocked }

/// Orchestrates Google account + recovery vault + Drive folder bootstrap.
class VaultService {
  VaultService({
    required this.encryption,
    required this.googleAuth,
    required this.drive,
  });

  static const _setupCompleteKey = 'secure_keep_setup_complete';

  final EncryptionService encryption;
  final GoogleAuthService googleAuth;
  final GoogleDriveService drive;

  Future<VaultPhase> currentPhase() async {
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool(_setupCompleteKey) ?? false;
    final hasKey = await encryption.hasStoredMasterKey();

    if (!setupDone || !hasKey) {
      return VaultPhase.needsSetup;
    }
    if (!encryption.isUnlocked) {
      return VaultPhase.needsUnlock;
    }
    return VaultPhase.unlocked;
  }

  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool(_setupCompleteKey) ?? false;
    final hasKey = await encryption.hasStoredMasterKey();
    return setupDone && hasKey;
  }

  /// First-time: Google Sign-In → create recovery vault → Drive folder.
  /// Returns the one-time 12-word mnemonic (show once, never again).
  Future<String> completeInitialSetup() async {
    final account = await googleAuth.signIn();
    if (account == null) {
      throw StateError('Google Sign-In was cancelled');
    }

    if ((await drive.listMemoFiles()).isNotEmpty) {
      throw StateError(
        'この Google Drive アカウントには既存の暗号化メモがあります。'
        '新規セットアップではなく、リカバリーコードで復元してください。',
      );
    }

    final mnemonic = await encryption.createVault();
    await drive.ensureFolder();
    await drive.ensureVaultMeta();

    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupCompleteKey, true);
    }
    return mnemonic;
  }

  Future<void> completeWebSetup() async {
    if (!kIsWeb) {
      throw UnsupportedError('This setup step is only available on Web');
    }
    await encryption.storeCurrentKeyWithPasskey();
  }

  Future<void> finishWebSetup() async {
    if (!kIsWeb || !encryption.isUnlocked) {
      throw StateError('Web setup must first protect the key with a passkey');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
  }

  /// Restore on a new device with the 12-word phrase + Google account.
  Future<void> restoreFromRecoveryPhrase(String mnemonic) async {
    if (kIsWeb) {
      await prepareWebRecovery(mnemonic);
      await completeWebRecovery();
      return;
    }

    if (!encryption.validateMnemonic(mnemonic)) {
      throw const FormatException('リカバリーコードが正しくありません');
    }

    final account = await googleAuth.signIn();
    if (account == null) {
      throw StateError('Google Sign-In was cancelled');
    }

    await encryption.unlockFromRecoveryPhrase(mnemonic);
    await drive.ensureFolder();
    await drive.ensureVaultMeta();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
  }

  Future<void> prepareWebRecovery(String mnemonic) async {
    if (!kIsWeb) {
      throw UnsupportedError('This recovery step is only available on Web');
    }
    if (!encryption.validateMnemonic(mnemonic)) {
      throw const FormatException('リカバリーコードが正しくありません');
    }
    await encryption.unlockFromRecoveryPhrase(mnemonic);
    await encryption.storeCurrentKeyWithPasskey(replaceExisting: true);
  }

  Future<void> completeWebRecovery() async {
    if (!kIsWeb || !encryption.isUnlocked) {
      throw StateError('Web recovery must first be unlocked with a passkey');
    }
    final account = await googleAuth.signIn();
    if (account == null) {
      throw StateError('Google Sign-In was cancelled');
    }
    await drive.ensureFolder();
    await drive.ensureVaultMeta();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
  }

  Future<void> unlockFromDevice() async {
    await encryption.unlockFromSecureStorage();
    await connectDrive();
  }

  Future<void> unlockDeviceKey() => encryption.unlockFromSecureStorage();

  Future<void> connectDrive() async {
    if (kIsWeb) {
      await googleAuth.signOut();
    } else if (await googleAuth.signInSilently() != null) {
      await drive.ensureFolder();
      return;
    }

    final account = await googleAuth.signIn();
    if (account == null) {
      throw StateError('Google Sign-In was cancelled');
    }
    await drive.ensureFolder();
  }

  void lock() {
    encryption.lock();
  }
}
