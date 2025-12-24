import 'package:equatable/equatable.dart';

/// Message role enum
enum MessageRole { user, assistant, system }

/// Message entity - Core business object for chat messages
class MessageEntity extends Equatable {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;
  final int? tokensUsed;

  const MessageEntity({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isError = false,
    this.tokensUsed,
  });

  /// Check if this is a user message
  bool get isUser => role == MessageRole.user;

  /// Check if this is an assistant message
  bool get isAssistant => role == MessageRole.assistant;

  /// Check if this is a system message
  bool get isSystem => role == MessageRole.system;

  MessageEntity copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    bool? isError,
    int? tokensUsed,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      tokensUsed: tokensUsed ?? this.tokensUsed,
    );
  }

  @override
  List<Object?> get props => [id, content, role, timestamp, isError, tokensUsed];
}

/// Chat conversation entity
class ConversationEntity extends Equatable {
  final String id;
  final String userId;
  final String? title;
  final List<MessageEntity> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationEntity({
    required this.id,
    required this.userId,
    this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the last message in the conversation
  MessageEntity? get lastMessage => messages.isNotEmpty ? messages.last : null;

  /// Get conversation title or generate from first message
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (messages.isEmpty) return 'New Chat';
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => messages.first,
    );
    final content = firstUserMessage.content;
    return content.length > 30 ? '${content.substring(0, 30)}...' : content;
  }

  ConversationEntity copyWith({
    String? id,
    String? userId,
    String? title,
    List<MessageEntity>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, title, messages, createdAt, updatedAt];
}

