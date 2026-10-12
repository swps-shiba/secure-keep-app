import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keep_app/services/encryption_service.dart';
import 'package:secure_keep_app/services/recovery_phrase_service.dart';

void main() {
  test('recovery phrase is 12 words and derives a stable AES key', () {
    final recovery = RecoveryPhraseService();
    final mnemonic = recovery.generateMnemonic();

    expect(recovery.wordsFrom(mnemonic), hasLength(12));
    expect(recovery.isValidMnemonic(mnemonic), isTrue);
    expect(
      recovery.deriveMasterKey(mnemonic).base64,
      recovery.deriveMasterKey(mnemonic).base64,
    );
  });

  test('invalid mnemonic is rejected', () {
    final recovery = RecoveryPhraseService();
    expect(
      recovery.isValidMnemonic('not a real phrase at all here now'),
      isFalse,
    );
  });

  test('AES-256 encrypt/decrypt round-trip after phrase unlock', () {
    final recovery = RecoveryPhraseService();
    final mnemonic = recovery.generateMnemonic();
    final encryption = EncryptionService(recoveryPhraseService: recovery);

    encryption.unlockInMemoryFromRecoveryPhrase(mnemonic);
    final payload = encryption.encryptJson({'hello': 'world', 'n': 1});
    final json = encryption.decryptJson(payload);

    expect(json['hello'], 'world');
    expect(json['n'], 1);

    encryption.lock();
    expect(encryption.isUnlocked, isFalse);
  });

  test('AES-256 encrypt/decrypt round-trip for binary attachments', () {
    final recovery = RecoveryPhraseService();
    final encryption = EncryptionService(recoveryPhraseService: recovery);
    encryption.unlockInMemoryFromRecoveryPhrase(recovery.generateMnemonic());
    final plainBytes = [0, 1, 2, 127, 128, 255];

    final ciphertext = encryption.encryptBytes(plainBytes);

    expect(ciphertext, isNot(plainBytes));
    expect(encryption.decryptBytes(ciphertext), plainBytes);
  });
}
