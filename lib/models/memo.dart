class Memo {
  const Memo({
    required this.id,
    required this.title,
    required this.accountId,
    required this.password,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.colorIndex = 0,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String accountId;
  final String password;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorIndex;
  final List<MemoAttachment> attachments;

  Memo copyWith({
    String? id,
    String? title,
    String? accountId,
    String? password,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorIndex,
    List<MemoAttachment>? attachments,
  }) {
    return Memo(
      id: id ?? this.id,
      title: title ?? this.title,
      accountId: accountId ?? this.accountId,
      password: password ?? this.password,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorIndex: colorIndex ?? this.colorIndex,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'accountId': accountId,
      'password': password,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorIndex': colorIndex,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
    };
  }

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      accountId: json['accountId'] as String? ?? '',
      password: json['password'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      colorIndex: json['colorIndex'] as int? ?? 0,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map(
            (attachment) =>
                MemoAttachment.fromJson(attachment as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class MemoAttachment {
  const MemoAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
  });

  final String id;
  final String name;
  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
  };

  factory MemoAttachment.fromJson(Map<String, dynamic> json) {
    return MemoAttachment(
      id: json['id'] as String,
      name: json['name'] as String,
      mimeType: json['mimeType'] as String,
    );
  }
}
