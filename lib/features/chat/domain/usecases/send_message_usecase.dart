import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

/// Use case for sending a message and getting AI response
class SendMessageUseCase {
  final ChatRepository repository;

  SendMessageUseCase(this.repository);

  /// Send message with optional system prompt for character personality
  Future<Either<Failure, MessageEntity>> call({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  }) async {
    // Validate message
    if (message.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'Message cannot be empty'));
    }

    if (message.length > 4000) {
      return const Left(ValidationFailure(message: 'Message is too long (max 4000 characters)'));
    }

    return await repository.sendMessage(
      conversationId: conversationId,
      message: message.trim(),
      history: history,
      systemPrompt: systemPrompt,
    );
  }
}

/// Use case for sending a message with streaming response
class SendMessageStreamUseCase {
  final ChatRepository repository;

  SendMessageStreamUseCase(this.repository);

  /// Send message with streaming and optional system prompt for character personality
  Stream<Either<Failure, String>> call({
    required String conversationId,
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  }) {
    // Validate message
    if (message.trim().isEmpty) {
      return Stream.value(const Left(ValidationFailure(message: 'Message cannot be empty')));
    }

    return repository.sendMessageStream(
      conversationId: conversationId,
      message: message.trim(),
      history: history,
      systemPrompt: systemPrompt,
    );
  }
}

