import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message_entity.dart';

/// Message Model - Data layer representation of MessageEntity
class MessageModel {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;
  final int? tokensUsed;
  final MessageType messageType;
  final String? imageUrl;
  final String? userId;

  const MessageModel({
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

  /// Factory constructor for user messages
  factory MessageModel.user({
    required String content,
    String? userId,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      userId: userId,
    );
  }

  /// Factory constructor for assistant messages
  factory MessageModel.assistant({
    required String content,
    int? tokensUsed,
    String? userId,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      tokensUsed: tokensUsed,
      userId: userId,
    );
  }

  /// Factory constructor for error messages
  factory MessageModel.error({
    required String content,
    String? userId,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isError: true,
      userId: userId,
    );
  }

  /// Factory constructor for image messages
  factory MessageModel.image({
    required String imageUrl,
    String? userId,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Image',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.image,
      imageUrl: imageUrl,
      userId: userId,
    );
  }

  /// Factory constructor for selfie request messages
  factory MessageModel.selfieRequest({
    String? userId,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Send me a selfie! 📸',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.selfieRequest,
      userId: userId,
    );
  }

  /// Factory constructor for selfie loading messages
  factory MessageModel.selfieLoading({
    String? userId,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Generating your selfie...',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.selfieLoading,
      userId: userId,
    );
  }

  /// Check if this is an image message
  bool get isImage => messageType == MessageType.image && imageUrl != null;

  /// Create from entity
  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      id: entity.id,
      content: entity.content,
      role: entity.role,
      timestamp: entity.timestamp,
      isError: entity.isError,
      tokensUsed: entity.tokensUsed,
      messageType: entity.messageType,
      imageUrl: entity.imageUrl,
      userId: entity.userId,
    );
  }

  /// Create from Firestore document
  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      content: data['content'] ?? data['text'] ?? '',
      role: _parseRole(data['role'] ?? 'user'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      isError: data['isError'] ?? false,
      tokensUsed: data['tokensUsed'],
      messageType: _parseMessageType(data['type'] ?? data['messageType'] ?? 'text'),
      imageUrl: data['imageUrl'],
      userId: data['userId'],
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'role': role.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'isError': isError,
      'tokensUsed': tokensUsed,
      'type': messageType.name,
      'imageUrl': imageUrl,
      'userId': userId,
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
      messageType: messageType,
      imageUrl: imageUrl,
      userId: userId,
    );
  }

  /// Parse role from string
  static MessageRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }

  /// Parse message type from string
  static MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'selfierequest':
      case 'selfie_request':
        return MessageType.selfieRequest;
      case 'selfieloading':
      case 'selfie_loading':
        return MessageType.selfieLoading;
      default:
        return MessageType.text;
    }
  }

  MessageModel copyWith({
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
    return MessageModel(
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
}

/// Conversation Model - Data layer representation of ConversationEntity
class ConversationModel {
  final String id;
  final String userId;
  final String characterId;
  final String? title;
  final List<MessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessageContent;
  final DateTime? lastMessageTimestamp;
  final int unreadCount;
  final String? characterName;
  final String? characterAvatar;

  const ConversationModel({
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

  /// Factory constructor to create a new conversation
  factory ConversationModel.create({
    required String id,
    required String userId,
    required String characterId,
    String? title,
    String? characterName,
    String? characterAvatar,
  }) {
    return ConversationModel(
      id: id,
      userId: userId,
      characterId: characterId,
      title: title,
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      characterName: characterName,
      characterAvatar: characterAvatar,
    );
  }

  /// Create from entity
  factory ConversationModel.fromEntity(ConversationEntity entity) {
    return ConversationModel(
      id: entity.id,
      userId: entity.userId,
      characterId: entity.characterId,
      title: entity.title,
      messages: entity.messages.map((m) => MessageModel.fromEntity(m)).toList(),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      lastMessageContent: entity.lastMessageContent,
      lastMessageTimestamp: entity.lastMessageTimestamp,
      unreadCount: entity.unreadCount,
      characterName: entity.characterName,
      characterAvatar: entity.characterAvatar,
    );
  }

  /// Create from Firestore document
  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConversationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      characterId: data['characterId'] ?? '',
      title: data['title'],
      messages: [], // Messages are loaded separately
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageContent: data['lastMessage'] ?? data['lastMessageContent'],
      lastMessageTimestamp: (data['lastMessageTimestamp'] as Timestamp?)?.toDate(),
      unreadCount: data['unreadCount'] ?? 0,
      characterName: data['characterName'],
      characterAvatar: data['characterAvatar'],
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'characterId': characterId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastMessage': lastMessageContent,
      'lastMessageTimestamp': lastMessageTimestamp != null
          ? Timestamp.fromDate(lastMessageTimestamp!)
          : null,
      'unreadCount': unreadCount,
      'characterName': characterName,
      'characterAvatar': characterAvatar,
    };
  }

  /// Convert to entity
  ConversationEntity toEntity() {
    return ConversationEntity(
      id: id,
      userId: userId,
      characterId: characterId,
      title: title,
      messages: messages.map((m) => m.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageContent: lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp,
      unreadCount: unreadCount,
      characterName: characterName,
      characterAvatar: characterAvatar,
    );
  }

  ConversationModel copyWith({
    String? id,
    String? userId,
    String? characterId,
    String? title,
    List<MessageModel>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessageContent,
    DateTime? lastMessageTimestamp,
    int? unreadCount,
    String? characterName,
    String? characterAvatar,
  }) {
    return ConversationModel(
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
}
