import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message_entity.dart';

/// Message model - Data layer representation
class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
    super.isError,
    super.tokensUsed,
  });

  /// Create from JSON (API response)
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? json['message'] ?? '',
      role: _parseRole(json['role'] ?? 'assistant'),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isError: json['is_error'] ?? false,
      tokensUsed: json['tokens_used'],
    );
  }

  /// Create from Firestore document
  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      content: data['content'] ?? '',
      role: _parseRole(data['role'] ?? 'user'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isError: data['isError'] ?? false,
      tokensUsed: data['tokensUsed'],
    );
  }

  /// Create from entity
  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      id: entity.id,
      content: entity.content,
      role: entity.role,
      timestamp: entity.timestamp,
      isError: entity.isError,
      tokensUsed: entity.tokensUsed,
    );
  }

  /// Create user message
  factory MessageModel.user({
    required String content,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
  }

  /// Create assistant message
  factory MessageModel.assistant({
    required String content,
    String? id,
    int? tokensUsed,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      tokensUsed: tokensUsed,
    );
  }

  /// Create error message
  factory MessageModel.error({
    required String content,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isError: true,
    );
  }

  /// Convert to JSON (for API request)
  Map<String, dynamic> toJson() {
    return {
      'role': _roleToString(role),
      'content': content,
    };
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'role': _roleToString(role),
      'timestamp': Timestamp.fromDate(timestamp),
      'isError': isError,
      'tokensUsed': tokensUsed,
    };
  }

  /// Convert to entity
  MessageEntity toEntity() {
    return MessageEntity(
      id: id,
      content: content,
      role: role,
      timestamp: timestamp,
      isError: isError,
      tokensUsed: tokensUsed,
    );
  }

  static MessageRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.assistant;
    }
  }

  static String _roleToString(MessageRole role) {
    switch (role) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }
}

/// Conversation model - Data layer representation
class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.userId,
    super.title,
    required super.messages,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create from Firestore document
  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'],
      messages: [], // Messages loaded separately
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create from entity
  factory ConversationModel.fromEntity(ConversationEntity entity) {
    return ConversationModel(
      id: entity.id,
      userId: entity.userId,
      title: entity.title,
      messages: entity.messages,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create new conversation
  factory ConversationModel.create({
    required String id,
    required String userId,
  }) {
    final now = DateTime.now();
    return ConversationModel(
      id: id,
      userId: userId,
      title: null,
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to entity
  ConversationEntity toEntity() {
    return ConversationEntity(
      id: id,
      userId: userId,
      title: title,
      messages: messages,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  ConversationModel copyWith({
    String? id,
    String? userId,
    String? title,
    List<MessageEntity>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

