import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/conversation_usecases.dart';
import '../../domain/usecases/send_message_usecase.dart';
import 'chat_providers.dart';

/// Chat state
class ChatState {
  final List<MessageEntity> messages;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final String currentStreamingContent;
  final String? conversationId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.error,
    this.currentStreamingContent = '',
    this.conversationId,
  });

  ChatState copyWith({
    List<MessageEntity>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? error,
    String? currentStreamingContent,
    String? conversationId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
      currentStreamingContent: currentStreamingContent ?? this.currentStreamingContent,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

/// Chat Controller - manages chat state and actions
class ChatController extends StateNotifier<ChatState> {
  final SendMessageUseCase _sendMessageUseCase;
  final SendMessageStreamUseCase _sendMessageStreamUseCase;
  final CreateConversationUseCase _createConversationUseCase;
  final Uuid _uuid = const Uuid();

  ChatController({
    required SendMessageUseCase sendMessageUseCase,
    required SendMessageStreamUseCase sendMessageStreamUseCase,
    required CreateConversationUseCase createConversationUseCase,
  })  : _sendMessageUseCase = sendMessageUseCase,
        _sendMessageStreamUseCase = sendMessageStreamUseCase,
        _createConversationUseCase = createConversationUseCase,
        super(const ChatState());

  /// Initialize new conversation
  Future<void> initConversation(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _createConversationUseCase(userId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (conversation) {
        state = state.copyWith(
          isLoading: false,
          conversationId: conversation.id,
          messages: [],
        );
      },
    );
  }

  /// Load existing conversation
  void loadConversation(ConversationEntity conversation) {
    state = state.copyWith(
      conversationId: conversation.id,
      messages: conversation.messages,
      error: null,
    );
  }

  /// Send message (non-streaming)
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (state.isLoading || state.isStreaming) return;

    final conversationId = state.conversationId;
    if (conversationId == null) return;

    // Add user message to UI immediately
    final userMessage = MessageModel.user(
      content: content,
      id: _uuid.v4(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    // Send to AI
    final result = await _sendMessageUseCase(
      conversationId: conversationId,
      message: content,
      history: state.messages.where((m) => !m.isError).toList(),
    );

    result.fold(
      (failure) {
        // Add error message
        final errorMessage = MessageModel.error(
          content: failure.message,
          id: _uuid.v4(),
        );
        state = state.copyWith(
          messages: [...state.messages, errorMessage],
          isLoading: false,
          error: failure.message,
        );
      },
      (response) {
        state = state.copyWith(
          messages: [...state.messages, response],
          isLoading: false,
        );
      },
    );
  }

  /// Send message with streaming response
  Future<void> sendMessageStream(String content) async {
    if (content.trim().isEmpty) return;
    if (state.isLoading || state.isStreaming) return;

    final conversationId = state.conversationId;
    if (conversationId == null) return;

    // Add user message to UI immediately
    final userMessage = MessageModel.user(
      content: content,
      id: _uuid.v4(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isStreaming: true,
      currentStreamingContent: '',
      error: null,
    );

    String fullContent = '';

    await for (final result in _sendMessageStreamUseCase(
      conversationId: conversationId,
      message: content,
      history: state.messages.where((m) => !m.isError).take(20).toList(),
    )) {
      result.fold(
        (failure) {
          final errorMessage = MessageModel.error(
            content: failure.message,
            id: _uuid.v4(),
          );
          state = state.copyWith(
            messages: [...state.messages, errorMessage],
            isStreaming: false,
            currentStreamingContent: '',
            error: failure.message,
          );
        },
        (chunk) {
          fullContent += chunk;
          state = state.copyWith(
            currentStreamingContent: fullContent,
          );
        },
      );
    }

    // Add completed message
    if (fullContent.isNotEmpty) {
      final assistantMessage = MessageModel.assistant(
        content: fullContent,
        id: _uuid.v4(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isStreaming: false,
        currentStreamingContent: '',
      );
    }
  }

  /// Clear chat
  void clearChat() {
    state = state.copyWith(
      messages: [],
      error: null,
      currentStreamingContent: '',
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Start new chat (reset conversation)
  Future<void> startNewChat(String userId) async {
    state = const ChatState();
    await initConversation(userId);
  }
}

/// Chat Controller Provider
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    sendMessageUseCase: ref.watch(sendMessageUseCaseProvider),
    sendMessageStreamUseCase: ref.watch(sendMessageStreamUseCaseProvider),
    createConversationUseCase: ref.watch(createConversationUseCaseProvider),
  );
});

