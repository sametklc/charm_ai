import 'package:equatable/equatable.dart';

/// Message role enum
enum MessageRole { user, assistant, system }

/// Message type enum
enum MessageType { text, image, selfieRequest, selfieLoading }

/// Message entity - Core business object for chat messages
class MessageEntity extends Equatable {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;
  final int? tokensUsed;
  
  /// Message type (text, image, selfie request, etc.)
  final MessageType messageType;
  
  /// Image URL for image messages
  final String? imageUrl;
  
  /// User ID who owns this message (for Firestore security rules)
  final String? userId;

  const MessageEntity({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isError = false,
    this.tokensUsed,
    this.messageType = MessageType.text,
    this.imageUrl,
    this.userId,
  });

  /// Check if this is a user message
  bool get isUser => role == MessageRole.user;

  /// Check if this is an assistant message
  bool get isAssistant => role == MessageRole.assistant;

  /// Check if this is a system message
  bool get isSystem => role == MessageRole.system;
  
  /// Check if this is an image message
  bool get isImage => messageType == MessageType.image && imageUrl != null;
  
  /// Check if this is a selfie request
  bool get isSelfieRequest => messageType == MessageType.selfieRequest;
  
  /// Check if selfie is loading
  bool get isSelfieLoading => messageType == MessageType.selfieLoading;

  MessageEntity copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    bool? isError,
    int? tokensUsed,
    MessageType? messageType,
    String? imageUrl,
    String? userId,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
    );
  }

  @override
  List<Object?> get props => [id, content, role, timestamp, isError, tokensUsed, messageType, imageUrl, userId];
}

/// Chat conversation entity
class ConversationEntity extends Equatable {
  final String id;
  final String userId;
  final String characterId;
  final String? title;
  final List<MessageEntity> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  /// Last message content (for quick display in chat list)
  final String? lastMessageContent;
  
  /// Last message timestamp
  final DateTime? lastMessageTimestamp;
  
  /// Unread message count
  final int unreadCount;
  
  /// Character name (for display in chat list)
  final String? characterName;
  
  /// Character avatar URL (for display in chat list)
  final String? characterAvatar;

  const ConversationEntity({
    required this.id,
    required this.userId,
    required this.characterId,
    this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageContent,
    this.lastMessageTimestamp,
    this.unreadCount = 0,
    this.characterName,
    this.characterAvatar,
  });

  /// Get the last message in the conversation
  MessageEntity? get lastMessage => messages.isNotEmpty ? messages.last : null;
  
  /// Get display last message (from field or from messages list)
  String get displayLastMessage {
    if (lastMessageContent != null && lastMessageContent!.isNotEmpty) {
      return lastMessageContent!;
    }
    if (messages.isNotEmpty) {
      final last = messages.last;
      if (last.isImage) return '📷 Photo';
      return last.content;
    }
    return 'Start chatting!';
  }
  
  /// Get display timestamp
  DateTime get displayTimestamp => lastMessageTimestamp ?? updatedAt;

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
    String? characterId,
    String? title,
    List<MessageEntity>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessageContent,
    DateTime? lastMessageTimestamp,
    int? unreadCount,
    String? characterName,
    String? characterAvatar,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      characterName: characterName ?? this.characterName,
      characterAvatar: characterAvatar ?? this.characterAvatar,
    );
  }

  @override
  List<Object?> get props => [
    id, userId, characterId, title, messages, createdAt, updatedAt,
    lastMessageContent, lastMessageTimestamp, unreadCount,
    characterName, characterAvatar,
  ];
}

