import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:encrypt/encrypt.dart' as enc;

/// Generates and validates a 12-word BIP39 recovery phrase, and derives the
/// AES-256 data-encryption key (DEK) from it.
///
/// Zero-knowledge: Google never sees this phrase. Only ciphertext is uploaded.
class RecoveryPhraseService {
  /// Creates a new 12-word English mnemonic.
  String generateMnemonic() {
    return bip39.generateMnemonic(strength: 128);
  }

  bool isValidMnemonic(String mnemonic) {
    final normalized = normalize(mnemonic);
    return bip39.validateMnemonic(normalized);
  }

  String normalize(String mnemonic) {
    return mnemonic
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
  }

  List<String> wordsFrom(String mnemonic) {
    return normalize(mnemonic).split(' ');
  }

  /// BIP39 seed (PBKDF2) → first 32 bytes as AES-256 key.
  enc.Key deriveMasterKey(String mnemonic) {
    final normalized = normalize(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('Invalid recovery phrase');
    }

    final seed = bip39.mnemonicToSeed(normalized);
    final keyBytes = Uint8List.fromList(seed.sublist(0, 32));
    return enc.Key(keyBytes);
  }
}
