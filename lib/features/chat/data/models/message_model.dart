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
    super.messageType,
    super.imageUrl,
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
      messageType: _parseMessageType(json['message_type']),
      imageUrl: json['image_url'],
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
      messageType: _parseMessageType(data['messageType']),
      imageUrl: data['imageUrl'],
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
      messageType: entity.messageType,
      imageUrl: entity.imageUrl,
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
  
  /// Create selfie request message (user asking for selfie)
  factory MessageModel.selfieRequest({String? id}) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Send me a selfie! 📸',
      role: MessageRole.user,
      timestamp: DateTime.now(),
      messageType: MessageType.selfieRequest,
    );
  }
  
  /// Create selfie loading message (while generating)
  factory MessageModel.selfieLoading({String? id}) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Taking a selfie for you... 📸',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.selfieLoading,
    );
  }
  
  /// Create image message (selfie response)
  factory MessageModel.image({
    required String imageUrl,
    String? caption,
    String? id,
  }) {
    return MessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: caption ?? 'Here\'s a selfie for you! 💕📸',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.image,
      imageUrl: imageUrl,
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
      'messageType': _messageTypeToString(messageType),
      'imageUrl': imageUrl,
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
    );
  }
  
  static MessageType _parseMessageType(String? type) {
    if (type == null) return MessageType.text;
    switch (type.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'selfierequest':
        return MessageType.selfieRequest;
      case 'selfieloading':
        return MessageType.selfieLoading;
      default:
        return MessageType.text;
    }
  }
  
  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.selfieRequest:
        return 'selfieRequest';
      case MessageType.selfieLoading:
        return 'selfieLoading';
    }
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
    required super.characterId,
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
      characterId: data['characterId'] ?? '',
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
      characterId: entity.characterId,
      title: entity.title,
      messages: entity.messages,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create new conversation with a character
  factory ConversationModel.create({
    required String id,
    required String userId,
    required String characterId,
    String? title,
  }) {
    final now = DateTime.now();
    return ConversationModel(
      id: id,
      userId: userId,
      characterId: characterId,
      title: title,
      messages: const [],
      createdAt: now,
      updatedAt: now,
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
    };
  }

  /// Convert to entity
  ConversationEntity toEntity() {
    return ConversationEntity(
      id: id,
      userId: userId,
      characterId: characterId,
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
    String? characterId,
    String? title,
    List<MessageEntity>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

