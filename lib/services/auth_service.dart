import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Handles biometric unlock with automatic fallback to the device PIN /
/// pattern / password when biometrics are unavailable or decline.
class AuthService {
  AuthService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> canAuthenticate() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported || canCheck;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    if (kIsWeb) {
      return const [];
    }

    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Requests unlock. Prefer biometrics, but allow device credentials
  /// (`biometricOnly: false`) so PIN / pattern / password remain usable.
  Future<bool> authenticate({String reason = '暗号化メモを表示するには認証が必要です'}) async {
    if (kIsWeb) {
      return true;
    }

    try {
      final canAuth = await canAuthenticate();
      if (!canAuth) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Secure Keep のロック解除',
            biometricHint: '指紋または顔で認証',
            cancelButton: 'キャンセル',
            deviceCredentialsRequiredTitle: 'デバイスのロック解除が必要です',
            deviceCredentialsSetupDescription:
                '設定で画面ロック（PIN / パターン / パスワード）を有効にしてください',
          ),
          IOSAuthMessages(
            cancelButton: 'キャンセル',
            goToSettingsButton: '設定を開く',
            goToSettingsDescription: 'Face ID / Touch ID またはパスコードを設定してください',
            lockOut: '生体認証がロックされています。デバイスのパスコードで解除してください',
          ),
        ],
        options: const AuthenticationOptions(
          // Fall back to device PIN / pattern / password automatically.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
