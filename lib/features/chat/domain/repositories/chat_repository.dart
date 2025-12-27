import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/message_entity.dart';

/// Chat Repository Interface
abstract class ChatRepository {
  /// Send a message and get AI response
  /// [systemPrompt] is the character's personality prompt for the AI
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  });

  /// Send message with streaming response
  /// [systemPrompt] is the character's personality prompt for the AI
  Stream<Either<Failure, String>> sendMessageStream({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  });

  /// Save conversation to Firestore
  Future<Either<Failure, void>> saveConversation(ConversationEntity conversation);

  /// Get conversation by ID
  Future<Either<Failure, ConversationEntity?>> getConversation(String conversationId);

  /// Get all conversations for a user
  Future<Either<Failure, List<ConversationEntity>>> getUserConversations(String userId);

  /// Get conversations for a user with a specific character
  Future<Either<Failure, List<ConversationEntity>>> getUserCharacterConversations(
    String userId,
    String characterId,
  );

  /// Delete conversation
  Future<Either<Failure, void>> deleteConversation(String conversationId);

  /// Delete all conversations for a user
  Future<Either<Failure, void>> deleteAllUserConversations(String userId);

  /// Create new conversation with a character
  Future<Either<Failure, ConversationEntity>> createConversation({
    required String userId,
    required String characterId,
    String? title,
    String? characterName,
    String? characterAvatar,
  });
}

