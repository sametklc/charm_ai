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
    print('🔵 ChatRepository: sendMessage called for conversationId: $conversationId');
    print('🔵 ChatRepository: Message length: ${message.length}, history length: ${history.length}');

    try {
      // NOTE: User message is already saved by ChatController
      // Here we only get the AI response

      // Get AI response with character's system prompt
      print('🔵 ChatRepository: Getting AI response...');
      final response = await remoteDataSource.sendMessage(
        message: message,
        history: history,
        systemPrompt: systemPrompt,
      );
      print('✅ ChatRepository: AI response received');

      // NOTE: AI response will be saved by ChatController
      // We just return it here

      return Right(response.toEntity());
    } on NetworkException catch (e) {
      print('❌ ChatRepository: NetworkException: ${e.message}');
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      print('❌ ChatRepository: ServerException: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.statusCode));
    } on AIGenerationException catch (e) {
      print('❌ ChatRepository: AIGenerationException: ${e.message}');
      return Left(AIGenerationFailure(message: e.message, modelName: e.modelName));
    } catch (e, stackTrace) {
      print('❌ ChatRepository: Unexpected error: $e');
      print('Stack trace: $stackTrace');
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
      // NOTE: User message is already saved by ChatController
      // Here we only stream the AI response

      // Stream AI response with character's system prompt
      await for (final chunk in remoteDataSource.sendMessageStream(
        message: message,
        history: history,
        systemPrompt: systemPrompt,
      )) {
        yield Right(chunk);
      }

      // NOTE: Complete AI response will be saved by ChatController
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
  Future<Either<Failure, void>> deleteAllUserConversations(String userId) async {
    try {
      await remoteDataSource.deleteAllUserConversations(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete all conversations'));
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
    String? characterName,
    String? characterAvatar,
  }) async {
    print('🔵 ChatRepository: createConversation called');
    print('🔵 ChatRepository: userId: $userId, characterId: $characterId, title: $title');
    print('🔵 ChatRepository: characterName: $characterName, characterAvatar: $characterAvatar');
    
    try {
      final conversationId = _uuid.v4();
      print('🔵 ChatRepository: Generated conversationId: $conversationId');
      
      final conversation = ConversationModel.create(
        id: conversationId,
        userId: userId,
        characterId: characterId,
        title: title,
        characterName: characterName,
        characterAvatar: characterAvatar,
      );
      print('✅ ChatRepository: ConversationModel created');

      print('🔵 ChatRepository: Saving conversation to Firestore...');
      await remoteDataSource.saveConversation(conversation);
      print('✅ ChatRepository: Conversation saved successfully');
      
      return Right(conversation.toEntity());
    } on ServerException catch (e) {
      print('❌ ChatRepository: ServerException creating conversation: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } catch (e, stackTrace) {
      print('❌ ChatRepository: Error creating conversation: $e');
      print('Stack trace: $stackTrace');
      return Left(ServerFailure(message: 'Failed to create conversation: $e'));
    }
  }
}

