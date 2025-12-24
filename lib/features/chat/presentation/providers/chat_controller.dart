import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/conversation_usecases.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../../media_generation/domain/entities/media_entity.dart';
import '../../../media_generation/domain/usecases/generate_image_usecase.dart';
import '../../../media_generation/presentation/providers/media_providers.dart';
import 'chat_providers.dart';

/// Chat state
class ChatState {
  final List<MessageEntity> messages;
  final bool isLoading;
  final bool isStreaming;
  final bool isSelfieLoading;
  final String? error;
  final String currentStreamingContent;
  final String? conversationId;
  final CharacterEntity? currentCharacter;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.isSelfieLoading = false,
    this.error,
    this.currentStreamingContent = '',
    this.conversationId,
    this.currentCharacter,
  });

  ChatState copyWith({
    List<MessageEntity>? messages,
    bool? isLoading,
    bool? isStreaming,
    bool? isSelfieLoading,
    String? error,
    String? currentStreamingContent,
    String? conversationId,
    CharacterEntity? currentCharacter,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      isSelfieLoading: isSelfieLoading ?? this.isSelfieLoading,
      error: error,
      currentStreamingContent: currentStreamingContent ?? this.currentStreamingContent,
      conversationId: conversationId ?? this.conversationId,
      currentCharacter: currentCharacter ?? this.currentCharacter,
    );
  }
}

/// Chat Controller - manages chat state and actions
class ChatController extends StateNotifier<ChatState> {
  final SendMessageUseCase _sendMessageUseCase;
  final SendMessageStreamUseCase _sendMessageStreamUseCase;
  final CreateConversationUseCase _createConversationUseCase;
  final GenerateImageUseCase _generateImageUseCase;
  final Uuid _uuid = const Uuid();

  ChatController({
    required SendMessageUseCase sendMessageUseCase,
    required SendMessageStreamUseCase sendMessageStreamUseCase,
    required CreateConversationUseCase createConversationUseCase,
    required GenerateImageUseCase generateImageUseCase,
  })  : _sendMessageUseCase = sendMessageUseCase,
        _sendMessageStreamUseCase = sendMessageStreamUseCase,
        _createConversationUseCase = createConversationUseCase,
        _generateImageUseCase = generateImageUseCase,
        super(const ChatState());

  /// Initialize new conversation with a character
  Future<void> initConversation(String userId, {CharacterEntity? character}) async {
    state = state.copyWith(isLoading: true, error: null, currentCharacter: character);

    final result = await _createConversationUseCase(
      userId: userId,
      characterId: character?.id ?? 'default',
      title: character != null ? 'Chat with ${character.name}' : null,
    );

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

  /// Set current character for the chat
  void setCharacter(CharacterEntity character) {
    state = state.copyWith(currentCharacter: character);
  }

  /// Load existing conversation
  void loadConversation(ConversationEntity conversation) {
    state = state.copyWith(
      conversationId: conversation.id,
      messages: conversation.messages,
      error: null,
    );
  }

  /// Send message (non-streaming) - with character personality
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

    // Send to AI with character's system prompt
    final result = await _sendMessageUseCase(
      conversationId: conversationId,
      message: content,
      history: state.messages.where((m) => !m.isError).toList(),
      systemPrompt: state.currentCharacter?.systemPrompt,
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

  /// Send message with streaming response - with character personality
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
      systemPrompt: state.currentCharacter?.systemPrompt,
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

  /// Request a selfie from the character
  Future<void> requestSelfie(String userId) async {
    if (state.isSelfieLoading || state.isLoading || state.isStreaming) return;
    
    final character = state.currentCharacter;
    if (character == null) return;

    // Add user's selfie request message
    final userMessage = MessageModel.selfieRequest(id: _uuid.v4());
    
    // Add loading message
    final loadingMessageId = _uuid.v4();
    final loadingMessage = MessageModel.selfieLoading(id: loadingMessageId);

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isSelfieLoading: true,
      error: null,
    );

    // Generate selfie using character's physical description
    final selfiePrompt = character.selfiePrompt;
    
    final params = ImageGenerationParams(
      prompt: selfiePrompt,
      negativePrompt: 'ugly, blurry, low quality, distorted face, extra fingers, bad anatomy, watermark, text, logo',
      width: 768,
      height: 1024, // Portrait orientation for selfie
      numOutputs: 1,
      model: 'flux-schnell', // Fast model for quick selfies
    );

    final result = await _generateImageUseCase(
      userId: userId,
      params: params,
    );

    // Remove loading message
    final messagesWithoutLoading = state.messages
        .where((m) => m.id != loadingMessageId)
        .toList();

    result.fold(
      (failure) {
        // Add error message
        final errorMessage = MessageModel.error(
          content: 'Oops! I couldn\'t take a selfie right now 😅 ${failure.message}',
          id: _uuid.v4(),
        );
        state = state.copyWith(
          messages: [...messagesWithoutLoading, errorMessage],
          isSelfieLoading: false,
          error: failure.message,
        );
      },
      (media) {
        // Add selfie image message
        final imageUrl = media.firstImageUrl;
        if (imageUrl != null) {
          final imageMessage = MessageModel.image(
            imageUrl: imageUrl,
            caption: _getSelfieCaptions(character),
            id: _uuid.v4(),
          );
          state = state.copyWith(
            messages: [...messagesWithoutLoading, imageMessage],
            isSelfieLoading: false,
          );
        } else {
          final errorMessage = MessageModel.error(
            content: 'Couldn\'t get the selfie 😢 Try again!',
            id: _uuid.v4(),
          );
          state = state.copyWith(
            messages: [...messagesWithoutLoading, errorMessage],
            isSelfieLoading: false,
          );
        }
      },
    );
  }
  
  /// Get random selfie caption based on character personality
  String _getSelfieCaptions(CharacterEntity character) {
    final captions = [
      'Here\'s a selfie for you! 💕📸',
      'Just took this for you! 😘',
      'Do you like it? 🥰',
      'Thinking of you... 💭💕',
      'Miss you already! 📸',
      'A little something for you 💕',
      'Just for you, ${character.name.split(' ').first} style! 😊',
    ];
    
    // Return random caption
    final random = DateTime.now().millisecondsSinceEpoch % captions.length;
    return captions[random];
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

  /// Start new chat (reset conversation) - with character
  Future<void> startNewChat(String userId, {CharacterEntity? character}) async {
    final currentChar = character ?? state.currentCharacter;
    state = ChatState(currentCharacter: currentChar);
    await initConversation(userId, character: currentChar);
  }
}

/// Chat Controller Provider
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    sendMessageUseCase: ref.watch(sendMessageUseCaseProvider),
    sendMessageStreamUseCase: ref.watch(sendMessageStreamUseCaseProvider),
    createConversationUseCase: ref.watch(createConversationUseCaseProvider),
    generateImageUseCase: ref.watch(generateImageUseCaseProvider),
  );
});
