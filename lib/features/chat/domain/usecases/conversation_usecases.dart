import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

/// Use case for creating a new conversation with a character
class CreateConversationUseCase {
  final ChatRepository repository;

  CreateConversationUseCase(this.repository);

  Future<Either<Failure, ConversationEntity>> call({
    required String userId,
    required String characterId,
    String? title,
  }) async {
    if (userId.isEmpty) {
      return const Left(ValidationFailure(message: 'User ID is required'));
    }
    if (characterId.isEmpty) {
      return const Left(ValidationFailure(message: 'Character ID is required'));
    }
    return await repository.createConversation(
      userId: userId,
      characterId: characterId,
      title: title,
    );
  }
}

/// Use case for getting user conversations
class GetConversationsUseCase {
  final ChatRepository repository;

  GetConversationsUseCase(this.repository);

  Future<Either<Failure, List<ConversationEntity>>> call(String userId) async {
    if (userId.isEmpty) {
      return const Left(ValidationFailure(message: 'User ID is required'));
    }
    return await repository.getUserConversations(userId);
  }
}

/// Use case for getting user conversations with a specific character
class GetCharacterConversationsUseCase {
  final ChatRepository repository;

  GetCharacterConversationsUseCase(this.repository);

  Future<Either<Failure, List<ConversationEntity>>> call({
    required String userId,
    required String characterId,
  }) async {
    if (userId.isEmpty) {
      return const Left(ValidationFailure(message: 'User ID is required'));
    }
    if (characterId.isEmpty) {
      return const Left(ValidationFailure(message: 'Character ID is required'));
    }
    return await repository.getUserCharacterConversations(userId, characterId);
  }
}

/// Use case for getting a single conversation
class GetConversationUseCase {
  final ChatRepository repository;

  GetConversationUseCase(this.repository);

  Future<Either<Failure, ConversationEntity?>> call(String conversationId) async {
    if (conversationId.isEmpty) {
      return const Left(ValidationFailure(message: 'Conversation ID is required'));
    }
    return await repository.getConversation(conversationId);
  }
}

/// Use case for saving a conversation
class SaveConversationUseCase {
  final ChatRepository repository;

  SaveConversationUseCase(this.repository);

  Future<Either<Failure, void>> call(ConversationEntity conversation) async {
    return await repository.saveConversation(conversation);
  }
}

/// Use case for deleting a conversation
class DeleteConversationUseCase {
  final ChatRepository repository;

  DeleteConversationUseCase(this.repository);

  Future<Either<Failure, void>> call(String conversationId) async {
    if (conversationId.isEmpty) {
      return const Left(ValidationFailure(message: 'Conversation ID is required'));
    }
    return await repository.deleteConversation(conversationId);
  }
}

