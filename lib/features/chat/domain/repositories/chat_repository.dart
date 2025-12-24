import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/message_entity.dart';

/// Chat Repository Interface
abstract class ChatRepository {
  /// Send a message and get AI response
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
  });

  /// Send message with streaming response
  Stream<Either<Failure, String>> sendMessageStream({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
  });

  /// Save conversation to Firestore
  Future<Either<Failure, void>> saveConversation(ConversationEntity conversation);

  /// Get conversation by ID
  Future<Either<Failure, ConversationEntity?>> getConversation(String conversationId);

  /// Get all conversations for a user
  Future<Either<Failure, List<ConversationEntity>>> getUserConversations(String userId);

  /// Delete conversation
  Future<Either<Failure, void>> deleteConversation(String conversationId);

  /// Create new conversation
  Future<Either<Failure, ConversationEntity>> createConversation(String userId);
}

