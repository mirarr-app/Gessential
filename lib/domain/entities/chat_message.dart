class ChatMessage {
  final String role;
  final String content;

  const ChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, String> toMap() {
    return {
      'role': role,
      'content': content,
    };
  }

  factory ChatMessage.fromMap(Map<String, String> map) {
    return ChatMessage(
      role: map['role'] ?? '',
      content: map['content'] ?? '',
    );
  }

  bool get isUser => role == 'user';
}
