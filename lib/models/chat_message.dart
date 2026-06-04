/// AIトレーナーチャットの1メッセージ。
enum ChatRole {
  user,
  trainer;

  /// プロキシ（Gemini）へ送る際の role 表現。
  String get apiRole => this == ChatRole.user ? 'user' : 'model';
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: ChatRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => ChatRole.trainer,
        ),
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
