import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keep_app/services/memo_cache_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'web memo cache stores, lists, reads, and deletes encrypted payloads',
    () async {
      SharedPreferences.setMockInitialValues({'unrelated_preference': 'value'});
      final cache = createMemoCache(namespace: 'test-account');

      await cache.write('memo-id', 'encrypted-payload');

      expect(await cache.listIds(), ['memo-id']);
      expect(await cache.read('memo-id'), 'encrypted-payload');
      final encryptedAttachment = Uint8List.fromList([0, 1, 127, 128, 255]);
      await cache.writeAttachment(
        'memo-id--attachment-id',
        encryptedAttachment,
      );
      expect(
        await cache.readAttachment('memo-id--attachment-id'),
        encryptedAttachment,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'unrelated_preference',
        ),
        'value',
      );

      await cache.delete('memo-id');
      await cache.deleteAttachment('memo-id--attachment-id');

      expect(await cache.listIds(), isEmpty);
      expect(await cache.read('memo-id'), isNull);
      expect(await cache.readAttachment('memo-id--attachment-id'), isNull);
    },
    skip: !kIsWeb,
  );

  test('web memo caches are isolated by account namespace', () async {
    SharedPreferences.setMockInitialValues({
      'secure_keep_encrypted_memo_legacy-id': 'legacy-payload',
    });
    final personalCache = createMemoCache(namespace: 'personal');
    final companyCache = createMemoCache(namespace: 'company');

    await personalCache.write('memo-id', 'personal-payload');
    await companyCache.write('memo-id', 'company-payload');

    expect(await personalCache.read('memo-id'), 'personal-payload');
    expect(await companyCache.read('memo-id'), 'company-payload');
    expect(await personalCache.listIds(), ['memo-id']);
    expect(await companyCache.listIds(), ['memo-id']);
    expect(await personalCache.read('legacy-id'), isNull);
    expect(await companyCache.read('legacy-id'), isNull);
  }, skip: !kIsWeb);
}
