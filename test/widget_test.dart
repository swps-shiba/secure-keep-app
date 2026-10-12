import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keep_app/models/memo.dart';

void main() {
  test('Memo serializes and deserializes', () {
    final now = DateTime.utc(2026, 10, 11, 8, 0);
    final memo = Memo(
      id: 'test-id',
      title: 'Bank',
      accountId: 'user@example.com',
      password: 'secret',
      content: 'note body',
      createdAt: now,
      updatedAt: now,
      colorIndex: 2,
      attachments: const [
        MemoAttachment(
          id: 'attachment-id',
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    final restored = Memo.fromJson(memo.toJson());

    expect(restored.id, memo.id);
    expect(restored.title, memo.title);
    expect(restored.accountId, memo.accountId);
    expect(restored.password, memo.password);
    expect(restored.content, memo.content);
    expect(restored.colorIndex, memo.colorIndex);
    expect(restored.attachments.single.id, 'attachment-id');
    expect(restored.attachments.single.isImage, isTrue);
  });

  test('Memo deserializes older payloads without attachment metadata', () {
    final now = DateTime.utc(2026, 10, 11, 8, 0);
    final restored = Memo.fromJson({
      'id': 'legacy-id',
      'title': 'Old memo',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    expect(restored.attachments, isEmpty);
  });
}
