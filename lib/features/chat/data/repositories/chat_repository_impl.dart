import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/message_model.dart';

/// Implementation of Chat Repository
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final Uuid _uuid = const Uuid();

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  }) async {
    try {
      // Create and save user message
      final userMessage = MessageModel.user(content: message);
      await remoteDataSource.saveMessage(conversationId, userMessage);

      // Get AI response with character's system prompt
      final response = await remoteDataSource.sendMessage(
        message: message,
        history: history,
        systemPrompt: systemPrompt,
      );

      // Save AI response
      await remoteDataSource.saveMessage(conversationId, response);

      return Right(response.toEntity());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.statusCode));
    } on AIGenerationException catch (e) {
      return Left(AIGenerationFailure(message: e.message, modelName: e.modelName));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to send message: ${e.toString()}'));
    }
  }

  @override
  Stream<Either<Failure, String>> sendMessageStream({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  }) async* {
    try {
      // Create and save user message
      final userMessage = MessageModel.user(content: message);
      await remoteDataSource.saveMessage(conversationId, userMessage);

      // Stream AI response with character's system prompt
      String fullResponse = '';
      await for (final chunk in remoteDataSource.sendMessageStream(
        message: message,
        history: history,
        systemPrompt: systemPrompt,
      )) {
        fullResponse += chunk;
        yield Right(chunk);
      }

      // Save complete AI response
      final assistantMessage = MessageModel.assistant(content: fullResponse);
      await remoteDataSource.saveMessage(conversationId, assistantMessage);
    } on NetworkException catch (e) {
      yield Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      yield Left(ServerFailure(message: e.message, code: e.statusCode));
    } on AIGenerationException catch (e) {
      yield Left(AIGenerationFailure(message: e.message, modelName: e.modelName));
    } catch (e) {
      yield Left(ServerFailure(message: 'Streaming failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> saveConversation(ConversationEntity conversation) async {
    try {
      await remoteDataSource.saveConversation(
        ConversationModel.fromEntity(conversation),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save conversation'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity?>> getConversation(String conversationId) async {
    try {
      final conversation = await remoteDataSource.getConversation(conversationId);
      return Right(conversation?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get conversation'));
    }
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> getUserConversations(String userId) async {
    try {
      final conversations = await remoteDataSource.getUserConversations(userId);
      return Right(conversations.map((c) => c.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get conversations'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteConversation(String conversationId) async {
    try {
      await remoteDataSource.deleteConversation(conversationId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete conversation'));
    }
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> getUserCharacterConversations(
    String userId,
    String characterId,
  ) async {
    try {
      final conversations = await remoteDataSource.getUserCharacterConversations(
        userId,
        characterId,
      );
      return Right(conversations.map((c) => c.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get character conversations'));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> createConversation({
    required String userId,
    required String characterId,
    String? title,
  }) async {
    try {
      final conversationId = _uuid.v4();
      final conversation = ConversationModel.create(
        id: conversationId,
        userId: userId,
        characterId: characterId,
        title: title,
      );

      await remoteDataSource.saveConversation(conversation);
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create conversation'));
    }
  }
}

