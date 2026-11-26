import 'semantic_profile.dart';

enum ChatRole { user, assistant }

enum ChatStatus { streaming, done, failed }

/// 一条对话消息。桌宠表情由 assistant 消息完成后附加的 [profile] 驱动。
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = ChatStatus.done,
    this.profile,
    this.reasoning,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final ChatStatus status;

  /// 该条回复的语义分析结果（仅 assistant）。
  final SemanticProfile? profile;

  /// deepseek-reasoner 的思维链（若有）。
  final String? reasoning;

  bool get isUser => role == ChatRole.user;
  bool get isStreaming => status == ChatStatus.streaming;

  ChatMessage copyWith({
    String? content,
    ChatStatus? status,
    SemanticProfile? profile,
    String? reasoning,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      status: status ?? this.status,
      profile: profile ?? this.profile,
      reasoning: reasoning ?? this.reasoning,
    );
  }

  /// 发给 API 的最小结构。
  Map<String, String> toApiJson() => {
    'role': isUser ? 'user' : 'assistant',
    'content': content,
  };
}
