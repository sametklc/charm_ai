import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/storage_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
  final String? characterGender; // Store gender from Firestore

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.isSelfieLoading = false,
    this.error,
    this.currentStreamingContent = '',
    this.conversationId,
    this.currentCharacter,
    this.characterGender,
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
    String? characterGender,
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
      characterGender: characterGender ?? this.characterGender,
    );
  }
}

/// Chat Controller - manages chat state and actions with Firebase Storage persistence
class ChatController extends StateNotifier<ChatState> {
  final SendMessageUseCase _sendMessageUseCase;
  final SendMessageStreamUseCase _sendMessageStreamUseCase;
  final CreateConversationUseCase _createConversationUseCase;
  final GetOrCreateConversationUseCase _getOrCreateConversationUseCase;
  final GenerateImageUseCase _generateImageUseCase;
  final StorageService _storageService;
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  ChatController({
    required SendMessageUseCase sendMessageUseCase,
    required SendMessageStreamUseCase sendMessageStreamUseCase,
    required CreateConversationUseCase createConversationUseCase,
    required GetOrCreateConversationUseCase getOrCreateConversationUseCase,
    required GenerateImageUseCase generateImageUseCase,
    required StorageService storageService,
    required FirebaseFirestore firestore,
  })  : _sendMessageUseCase = sendMessageUseCase,
        _sendMessageStreamUseCase = sendMessageStreamUseCase,
        _createConversationUseCase = createConversationUseCase,
        _getOrCreateConversationUseCase = getOrCreateConversationUseCase,
        _generateImageUseCase = generateImageUseCase,
        _storageService = storageService,
        _firestore = firestore,
        super(const ChatState());

  /// Initialize conversation with a character (get existing or create new)
  Future<void> initConversation(String userId, {CharacterEntity? character}) async {
    print('🔵 ChatController: ========== initConversation START ==========');
    print('🔵 ChatController: userId: $userId');
    print('🔵 ChatController: character: ${character?.name ?? "null"} (${character?.id ?? "null"})');
    
    if (character == null) {
      print('❌ ChatController: Character is null, cannot initialize conversation');
      return;
    }
    
    // GUARD: Prevent duplicate initialization for same character
    if (state.isLoading && state.currentCharacter?.id == character.id) {
      print('⚠️ ChatController: Already initializing conversation for this character, skipping');
      return;
    }
    
    // GUARD: If conversation already exists for this character, skip
    if (state.conversationId != null && 
        state.currentCharacter?.id == character.id && 
        !state.isLoading) {
      print('⚠️ ChatController: Conversation already exists for this character: ${state.conversationId}');
      return;
    }
    
    // Load gender from Firestore
    final gender = await _loadCharacterGender(character.id);
    print('🔵 ChatController: Loaded gender: $gender');
    
    print('🔵 ChatController: Setting loading state...');
    state = state.copyWith(
      isLoading: true, 
      error: null, 
      currentCharacter: character,
      characterGender: gender,
      conversationId: null,
      messages: [],
      currentStreamingContent: null,
      isStreaming: false,
    );
    print('✅ ChatController: State reset - character: ${character.id}');

    // Use getOrCreate to avoid duplicate conversations
    print('🔵 ChatController: Calling getOrCreateConversationUseCase...');
    print('🔵 ChatController: Parameters - userId: $userId, characterId: ${character.id}, characterName: ${character.name}, characterAvatar: "${character.avatarUrl.substring(0, character.avatarUrl.length > 50 ? 50 : character.avatarUrl.length)}${character.avatarUrl.length > 50 ? "..." : ""}"');
    
    final result = await _getOrCreateConversationUseCase(
      userId: userId,
      characterId: character.id,
      characterName: character.name,
      characterAvatar: character.avatarUrl,
    );

    await result.fold(
      (failure) async {
        print('❌ ChatController: Failed to get/create conversation: ${failure.message}');
        print('🔵 ChatController: ========== initConversation END (FAILED) ==========');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (conversation) async {
        print('✅ ChatController: Conversation initialized: ${conversation.id}');
        print('🔵 ChatController: Conversation details:');
        print('🔵 ChatController:   - characterId: ${conversation.characterId}');
        print('🔵 ChatController:   - characterName: "${conversation.characterName}"');
        print('🔵 ChatController:   - characterAvatar: "${conversation.characterAvatar != null && conversation.characterAvatar!.length > 50 ? "${conversation.characterAvatar!.substring(0, 50)}..." : conversation.characterAvatar}"');
        print('🔵 ChatController:   - messages count: ${conversation.messages.length}');

        // If conversation has messages, use them. Otherwise load from Firestore
        List<MessageEntity> messagesToUse = conversation.messages;

        if (conversation.messages.isEmpty) {
          print('🔵 ChatController: No messages in conversation, loading from Firestore...');
          try {
            final messagesQuery = await _firestore
                .collection('conversations')
                .doc(conversation.id)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .get();

            final loadedMessages = messagesQuery.docs
                .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id).toEntity())
                .toList();

            messagesToUse = loadedMessages;
            print('✅ ChatController: Loaded ${loadedMessages.length} messages from Firestore');
          } catch (e) {
            print('❌ ChatController: Error loading messages: $e');
            // Continue with empty messages
          }
        }

        // Load gender if not already loaded
        final gender = state.characterGender ?? await _loadCharacterGender(character.id);
        
        state = state.copyWith(
          isLoading: false,
          conversationId: conversation.id,
          messages: messagesToUse,
          characterGender: gender,
        );
        print('✅ ChatController: State updated with conversationId: ${conversation.id}, messages: ${messagesToUse.length}');
        print('🔵 ChatController: ========== initConversation END (SUCCESS) ==========');
      },
    );
  }

  /// Set current character for the chat
  void setCharacter(CharacterEntity character, {String? gender}) {
    state = state.copyWith(
      currentCharacter: character,
      characterGender: gender,
    );
  }
  
  /// Load character gender from Firestore
  Future<String?> _loadCharacterGender(String characterId) async {
    try {
      final doc = await _firestore.collection('characters').doc(characterId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['gender']?.toString();
      }
    } catch (e) {
      print('⚠️ ChatController: Error loading character gender: $e');
    }
    return null;
  }

  /// Clear all messages in current conversation
  void clearMessages() {
    print('🔵 ChatController: clearMessages called');
    state = state.copyWith(messages: []);
    _saveMessagesToLocal([]);
    print('✅ ChatController: Messages cleared');
  }

  /// Save messages to local storage
  Future<void> _saveMessagesToLocal(List<MessageEntity> messages) async {
    try {
      final prefs = await _prefs;
      final conversationId = state.conversationId;
      if (conversationId == null) return;

      // Convert messages to JSON
      final messagesJson = messages.map((msg) => {
        'id': msg.id,
        'content': msg.content,
        'role': msg.role.name,
        'timestamp': msg.timestamp.toIso8601String(),
        'isError': msg.isError,
        'messageType': msg.messageType.name,
        'imageUrl': msg.imageUrl,
      }).toList();

      await prefs.setString('chat_messages_$conversationId', messagesJson.toString());
      print('✅ ChatController: Saved ${messages.length} messages to local storage');
    } catch (e) {
      print('❌ ChatController: Error saving messages to local storage: $e');
    }
  }

  /// Load messages from local storage
  Future<List<MessageEntity>> _loadMessagesFromLocal(String conversationId) async {
    try {
      final prefs = await _prefs;
      final messagesJson = prefs.getString('chat_messages_$conversationId');
      if (messagesJson == null) return [];

      // Parse JSON and convert to MessageEntity
      // For simplicity, return empty list for now - we can implement full parsing later
      print('✅ ChatController: Found local messages for conversation $conversationId');
      return [];
    } catch (e) {
      print('❌ ChatController: Error loading messages from local storage: $e');
      return [];
    }
  }

  /// Reset conversation state (when switching characters)
  void resetConversation() {
    print('🔵 ChatController: resetConversation called');
    print('🔵 ChatController: Previous state - conversationId: ${state.conversationId}, messages: ${state.messages.length}');
    state = state.copyWith(
      conversationId: null,
      messages: [], // CRITICAL: Clear all messages to prevent leakage
      error: null,
      isLoading: false,
      isStreaming: false,
      currentStreamingContent: null,
      currentCharacter: null, // Also clear character to force re-initialization
    );
    print('✅ ChatController: Conversation state FULLY reset');
  }

  /// Update messages from stream
  void updateMessages(List<MessageEntity> messages, {String? forConversationId}) {
    // CRITICAL: Only update if conversationId matches the one this update is intended for
    // If conversationId is null, reject all updates (prevent message leakage during initialization)
    if (state.conversationId == null) {
      print('⚠️ ChatController: updateMessages REJECTED - conversationId is null (initialization in progress)');
      return;
    }
    
    if (forConversationId != null && forConversationId != state.conversationId) {
      print('⚠️ ChatController: updateMessages REJECTED - ID mismatch. Current: ${state.conversationId}, Expected: $forConversationId');
      return;
    }
    
    print('✅ ChatController: updateMessages accepted for ${state.conversationId} (${messages.length} messages)');
    state = state.copyWith(messages: messages);
  }

  /// Load conversation by ID - Used when navigating from ChatHistoryScreen
  /// This is the most reliable way to ensure correct conversation is loaded
  Future<void> loadConversationById(String conversationId, CharacterEntity? character) async {
    print('🔵 ChatController: ========== loadConversationById START ==========');
    print('🔵 ChatController: conversationId: $conversationId');
    print('🔵 ChatController: character: ${character?.name ?? "null"} (${character?.id ?? "null"})');
    
    try {
      // Load gender if character provided
      String? gender;
      if (character != null) {
        gender = await _loadCharacterGender(character.id);
        print('🔵 ChatController: Loaded gender: $gender');
      }
      
      // Set loading state
      state = state.copyWith(
        isLoading: true,
        error: null,
        conversationId: conversationId,
        currentCharacter: character,
        characterGender: gender,
      );
      print('🔵 ChatController: State updated - conversationId: $conversationId, characterId: ${character?.id}');
      
      // Load messages from Firestore
      print('🔵 ChatController: Loading messages from Firestore...');
      final messagesQuery = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();
      
      print('🔵 ChatController: Firestore returned ${messagesQuery.docs.length} messages');
      
      final messages = messagesQuery.docs
          .map((doc) {
            print('🔵 ChatController: Parsing message ${doc.id}');
            return MessageModel.fromFirestore(doc.data(), doc.id).toEntity();
          })
          .toList();

      print('✅ ChatController: Loaded ${messages.length} messages from Firestore');

      // If no messages from Firestore, try local storage
      List<MessageEntity> finalMessages = messages;
      if (messages.isEmpty) {
        print('🔵 ChatController: No messages from Firestore, trying local storage...');
        final localMessages = await _loadMessagesFromLocal(conversationId);
        if (localMessages.isNotEmpty) {
          finalMessages = localMessages;
          print('✅ ChatController: Loaded ${localMessages.length} messages from local storage');
        }
      }

      for (int i = 0; i < finalMessages.length; i++) {
        final msg = finalMessages[i];
        print('  Final Message $i: ${msg.role.name} - "${msg.content.substring(0, min(30, msg.content.length))}${msg.content.length > 30 ? "..." : ""}"');
      }

      // Ensure gender is loaded if character exists
      final finalGender = character != null 
          ? (state.characterGender ?? await _loadCharacterGender(character.id))
          : state.characterGender;
      
      // Update state with messages
      final oldMessageCount = state.messages.length;
      state = state.copyWith(
        isLoading: false,
        messages: finalMessages,
        characterGender: finalGender,
        error: null,
      );

      // Save to local storage for future use
      if (finalMessages.isNotEmpty) {
        await _saveMessagesToLocal(finalMessages);
      }

      print('✅ ChatController: State updated with ${finalMessages.length} messages (was $oldMessageCount)');
      print('🔵 ChatController: ========== loadConversationById END (SUCCESS) ==========');
      print('🔵 ChatController: ========== loadConversationById END (SUCCESS) ==========');
    } catch (e, stackTrace) {
      print('❌ ChatController: Error loading conversation by ID: $e');
      print('Stack trace: $stackTrace');
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load conversation: $e',
      );
      print('🔵 ChatController: ========== loadConversationById END (FAILED) ==========');
    }
  }

  /// Load existing conversation with messages
  Future<void> loadConversation(ConversationEntity conversation) async {
    print('🔵 ChatController: ========== loadConversation START ==========');
    print('🔵 ChatController: conversationId: ${conversation.id}');
    print('🔵 ChatController: characterId: ${conversation.characterId}');
    print('🔵 ChatController: characterName: "${conversation.characterName}"');
    print('🔵 ChatController: characterAvatar: "${conversation.characterAvatar != null && conversation.characterAvatar!.length > 50 ? "${conversation.characterAvatar!.substring(0, 50)}..." : conversation.characterAvatar}"');
    print('🔵 ChatController: Conversation has ${conversation.messages.length} messages');
    print('🔵 ChatController: Current state - conversationId: ${state.conversationId}, characterId: ${state.currentCharacter?.id}');
    
    // CRITICAL: Verify conversation belongs to current character
    if (state.currentCharacter != null && conversation.characterId != state.currentCharacter!.id) {
      print('⚠️ ChatController: Conversation characterId (${conversation.characterId}) does not match current character (${state.currentCharacter!.id}). Not loading conversation.');
      print('🔵 ChatController: ========== loadConversation END (SKIPPED - CHARACTER MISMATCH) ==========');
      return;
    }
    
    // Set conversationId and existing messages
    state = state.copyWith(
      conversationId: conversation.id,
      messages: conversation.messages,
      error: null,
    );
    print('✅ ChatController: State updated with conversationId: ${conversation.id}');
    
    // If messages are empty, try to load them from Firestore
    List<MessageEntity> loadedMessages = conversation.messages;
    if (conversation.messages.isEmpty) {
      print('🔵 ChatController: No messages in conversation, loading from Firestore...');
      try {
        print('🔵 ChatController: Querying Firestore for messages in conversation ${conversation.id}');
        final messagesQuery = await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .get();
        print('🔵 ChatController: Firestore returned ${messagesQuery.docs.length} message documents');
        loadedMessages = messagesQuery.docs
            .map((doc) {
              print('🔵 ChatController: Parsing message ${doc.id}');
              return MessageModel.fromFirestore(doc.data(), doc.id).toEntity();
            })
            .toList();
        print('✅ ChatController: Loaded ${loadedMessages.length} messages from Firestore');
      } catch (e, stackTrace) {
        print('❌ ChatController: Error loading messages from Firestore: $e');
        print('Stack trace: $stackTrace');
        // Continue with empty messages
      }
    } else {
      print('✅ ChatController: Using ${conversation.messages.length} messages from conversation entity');
    }

    // Update state with loaded messages
    state = state.copyWith(
      conversationId: conversation.id,
      messages: loadedMessages,
      error: null,
    );
    print('✅ ChatController: State updated with conversationId: ${conversation.id}, messages count: ${loadedMessages.length}');
    print('🔵 ChatController: ========== loadConversation END ==========');
  }

  /// Send message (non-streaming) - with character personality
  Future<void> sendMessage(String content) async {
    print('🔵 ChatController: sendMessage called with content: "${content.substring(0, content.length > 50 ? 50 : content.length)}${content.length > 50 ? "..." : ""}"');
    
    if (content.trim().isEmpty) {
      print('⚠️ ChatController: Message is empty, ignoring');
      return;
    }
    
    if (state.isLoading || state.isStreaming) {
      print('⚠️ ChatController: Already loading/streaming, ignoring message');
      return;
    }

    final conversationId = state.conversationId;
    if (conversationId == null) {
      print('❌ ChatController: conversationId is null, cannot send message');
      return;
    }
    
    // Check if this is a contextual photo request
    const photoPrefix = '📸 Describe photo: ';
    if (content.startsWith(photoPrefix)) {
      print('📸 ChatController: Detected contextual photo request');
      final scenarioPrompt = content.substring(photoPrefix.length).trim();
      if (scenarioPrompt.isEmpty) {
        print('⚠️ ChatController: Photo request has no scenario description');
        return;
      }
      
      // Add user message to UI
      final userMessage = MessageEntity(
        id: _uuid.v4(),
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );
      
      state = state.copyWith(
        messages: [...state.messages, userMessage],
        error: null,
      );
      
      // Save user message to Firestore
      try {
        await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(userMessage));
      } catch (e) {
        print('❌ ChatController: Error saving photo request message: $e');
      }
      
      // Generate contextual photo
      // Get userId from FirebaseAuth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ ChatController: No authenticated user for photo generation');
        final errorMessage = MessageEntity(
          id: _uuid.v4(),
          content: 'Please log in to request photos',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          isError: true,
        );
        state = state.copyWith(
          messages: [...state.messages, errorMessage],
        );
        return;
      }
      await _generateContextualPhoto(userId: currentUser.uid, scenarioPrompt: scenarioPrompt);
      return;
    }
    
    print('✅ ChatController: conversationId: $conversationId');
    print('✅ ChatController: Character: ${state.currentCharacter?.name ?? "null"}');

    // Add user message to UI immediately
    final userMessage = MessageEntity(
      id: _uuid.v4(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    
    print('🔵 ChatController: Created user message with ID: ${userMessage.id}');

    // Add user message and set loading state for typing indicator
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true, // Show typing indicator while waiting for AI response
      error: null,
    );

    print('✅ ChatController: User message added to state, total messages: ${state.messages.length}');

    // Save messages to local storage
    await _saveMessagesToLocal(state.messages);
    print('🔵 ChatController: isLoading set to true for typing indicator');

      // Save user message to Firestore
      print('🔵 ChatController: Saving user message to Firestore...');

      try {
        await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(userMessage));
      print('✅ ChatController: User message saved to Firestore');
    } catch (e) {
      print('❌ ChatController: Error saving user message to Firestore: $e');
    }

    // Send to AI with character's system prompt
    print('🔵 ChatController: Sending message to AI...');
    print('🔵 ChatController: History length: ${state.messages.where((m) => !m.isError).length}');
    print('🔵 ChatController: System prompt: ${state.currentCharacter?.systemPrompt != null ? "Present" : "Missing"}');
    
    final result = await _sendMessageUseCase(
      conversationId: conversationId,
      message: content,
      history: state.messages.where((m) => !m.isError).toList(),
      systemPrompt: state.currentCharacter?.systemPrompt,
    );

    result.fold(
      (failure) {
        print('❌ ChatController: AI response failed: ${failure.message}');
        // Add error message and clear loading state
        final errorMessage = MessageEntity(
          id: _uuid.v4(),
          content: failure.message,
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          isError: true,
        );
        state = state.copyWith(
          messages: [...state.messages, errorMessage],
          isLoading: false, // Clear typing indicator
          error: failure.message,
        );
        print('✅ ChatController: Error message added to state');
      },
      (response) async {
        print('✅ ChatController: AI response received: "${response.content.substring(0, response.content.length > 50 ? 50 : response.content.length)}${response.content.length > 50 ? "..." : ""}"');
        state = state.copyWith(
          messages: [...state.messages, response],
          isLoading: false, // Clear typing indicator
        );
        print('✅ ChatController: AI response added to state, total messages: ${state.messages.length}');

        // Save messages to local storage
        await _saveMessagesToLocal(state.messages);

        // Save assistant message to Firestore
        print('🔵 ChatController: Saving AI response to Firestore...');
        if (conversationId != null) {
          try {
            final messageModel = MessageModel.fromEntity(response);
            await _saveMessageToFirestore(conversationId, messageModel);
            print('✅ ChatController: AI response saved to Firestore');
          } catch (e, stackTrace) {
            print('❌ ChatController: Error saving AI response to Firestore: $e');
            print('Stack trace: $stackTrace');
          }
        } else {
          print('⚠️ ChatController: Cannot save AI response - conversationId is null');
        }
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
    final userMessage = MessageEntity(
      id: _uuid.v4(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isStreaming: true,
      currentStreamingContent: '',
      error: null,
    );

    // Save user message to Firestore
    await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(userMessage));

    String fullContent = '';

    await for (final result in _sendMessageStreamUseCase(
      conversationId: conversationId,
      message: content,
      history: state.messages.where((m) => !m.isError).take(20).toList(),
      systemPrompt: state.currentCharacter?.systemPrompt,
    )) {
      result.fold(
        (failure) {
          final errorMessage = MessageEntity(
            id: _uuid.v4(),
            content: failure.message,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            isError: true,
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
      final assistantMessage = MessageEntity(
        id: _uuid.v4(),
        content: fullContent,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isStreaming: false,
        currentStreamingContent: '',
      );
      // Save assistant message to Firestore
      await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(assistantMessage));
    }
  }

  /// Request a selfie from the character - with Firebase Storage persistence
  Future<void> requestSelfie(String userId) async {
    if (state.isSelfieLoading || state.isLoading || state.isStreaming) return;
    
    final character = state.currentCharacter;
    final conversationId = state.conversationId;
    if (character == null || conversationId == null) return;

    // Add user's selfie request message
    final userMessage = MessageEntity(
      id: _uuid.v4(),
      content: 'Send me a selfie! 📸',
      role: MessageRole.user,
      timestamp: DateTime.now(),
      messageType: MessageType.selfieRequest,
    );
    
    // Add loading message
    final loadingMessageId = _uuid.v4();
    final loadingMessage = MessageEntity(
      id: loadingMessageId,
      content: 'Generating your selfie...',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.selfieLoading,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isSelfieLoading: true,
      error: null,
    );

    // Save selfie request to Firestore
    await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(userMessage));

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

    await result.fold(
      (failure) async {
        // Add error message
        final errorMessage = MessageEntity(
          id: _uuid.v4(),
          content: 'Oops! I couldn\'t take a selfie right now 😅 ${failure.message}',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          isError: true,
        );
        state = state.copyWith(
          messages: [...messagesWithoutLoading, errorMessage],
          isSelfieLoading: false,
          error: failure.message,
        );
      },
      (media) async {
        // Get temporary URL from AI service
        final tempUrl = media.firstImageUrl;
        if (tempUrl != null) {
          // Upload to Firebase Storage for permanent URL
          final storagePath = _storageService.generateChatMediaPath(conversationId);
          final permanentUrl = await _storageService.downloadAndUpload(
            sourceUrl: tempUrl,
            storagePath: storagePath,
          );

          if (permanentUrl != null) {
            // Add selfie image message with permanent URL
            final imageMessage = MessageEntity(
              id: _uuid.v4(),
              content: _getSelfieCaptions(character),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              messageType: MessageType.image,
              imageUrl: permanentUrl,
            );
            state = state.copyWith(
              messages: [...messagesWithoutLoading, imageMessage],
              isSelfieLoading: false,
            );
            // Save image message to Firestore
            await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(imageMessage));
          } else {
            // Fallback to temporary URL if storage upload fails
            final imageMessage = MessageEntity(
              id: _uuid.v4(),
              content: _getSelfieCaptions(character),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              messageType: MessageType.image,
              imageUrl: tempUrl,
            );
            state = state.copyWith(
              messages: [...messagesWithoutLoading, imageMessage],
              isSelfieLoading: false,
            );
            await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(imageMessage));
          }
        } else {
          final errorMessage = MessageEntity(
            id: _uuid.v4(),
            content: 'Couldn\'t get the selfie 😢 Try again!',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            isError: true,
          );
          state = state.copyWith(
            messages: [...messagesWithoutLoading, errorMessage],
            isSelfieLoading: false,
          );
        }
      },
    );
  }

  /// Generate contextual photo with character identity preservation
  Future<void> _generateContextualPhoto({
    required String userId,
    required String scenarioPrompt,
  }) async {
    print('📸 ChatController: _generateContextualPhoto called');
    print('📸 ChatController: scenarioPrompt: $scenarioPrompt');
    
    final character = state.currentCharacter;
    final conversationId = state.conversationId;
    if (character == null || conversationId == null) {
      print('❌ ChatController: Character or conversationId is null');
      return;
    }

    // Add loading message
    final loadingMessageId = _uuid.v4();
    final loadingMessage = MessageEntity(
      id: loadingMessageId,
      content: 'Generating photo...',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      messageType: MessageType.image,
    );

    state = state.copyWith(
      messages: [...state.messages, loadingMessage],
      isSelfieLoading: true,
      error: null,
    );

    // Build prompt for Flux PuLID: "Action First" rule
    // Format: "${userScenario}. A photo of ${characterName}, ${characterPhysicalDescription}. High quality."
    // main_face_image handles identity, so prompt should focus on ACTION first, then character context
    String fullPrompt;
    
    // Clean scenario prompt - remove any redundant descriptors
    String cleanScenario = scenarioPrompt.trim();
    
    // Get character name and physical description
    String characterName = character.name;
    String characterDesc = character.physicalDescription.isNotEmpty 
        ? character.physicalDescription 
        : 'photorealistic person';
    
    // Build prompt following "Action First" rule for scenario changes
    // Action/scenario comes first, then character context
    fullPrompt = '$cleanScenario. A photo of $characterName, $characterDesc. Cinematic lighting, 8k, high quality';
    
    print('📸 ChatController: Scenario prompt: $scenarioPrompt');
    print('📸 ChatController: Character name: $characterName');
    print('📸 ChatController: Character description: $characterDesc');
    print('📸 ChatController: Full prompt: $fullPrompt');
    print('📸 ChatController: Reference image URL (main_face_image): ${character.avatarUrl}');
    print('📸 ChatController: Using Flux PuLID for identity preservation');

    // Generate image with Flux PuLID for identity preservation
    // Width/Height optimized for ByteDance Flux PuLID (832x1216 default)
    final params = ImageGenerationParams(
      prompt: fullPrompt,
      referenceImageUrl: character.avatarUrl, // Will be sent as main_face_image to Flux PuLID
      negativePrompt: 'ugly, deformed, noisy, blurry, low quality, distorted face, bad anatomy, watermark, text, logo, different person, face mismatch',
      width: 832, // ByteDance Flux PuLID optimized size
      height: 1216,
      numOutputs: 1,
      model: 'flux-pulid', // Use Flux PuLID for identity preservation
      guidanceScale: 3.5, // Standard for Flux PuLID
      numInferenceSteps: 20, // Recommended steps for Flux PuLID
    );

    print('📸 ChatController: Calling _generateImageUseCase...');
    print('📸 ChatController: Params: prompt="${params.prompt}", model="${params.model}", referenceImageUrl="${params.referenceImageUrl}"');
    
    try {
      final result = await _generateImageUseCase(
        userId: userId,
        params: params,
      );
      print('📸 ChatController: Image generation use case completed');

      // Remove loading message
      final messagesWithoutLoading = state.messages
          .where((m) => m.id != loadingMessageId)
          .toList();

      await result.fold(
        (failure) async {
          print('❌ ChatController: Contextual photo generation failed: ${failure.message}');
          print('❌ ChatController: Failure type: ${failure.runtimeType}');
        final errorMessage = MessageEntity(
          id: _uuid.v4(),
          content: 'Couldn\'t generate the photo right now 😅 ${failure.message}',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          isError: true,
        );
        state = state.copyWith(
          messages: [...messagesWithoutLoading, errorMessage],
          isSelfieLoading: false,
          error: failure.message,
        );
        // Save error message to Firestore
        await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(errorMessage));
      },
      (media) async {
        print('✅ ChatController: Contextual photo generated successfully');
        final tempUrl = media.firstImageUrl;
        if (tempUrl != null) {
          // Upload to Firebase Storage for permanent URL
          final storagePath = _storageService.generateChatMediaPath(conversationId);
          final permanentUrl = await _storageService.downloadAndUpload(
            sourceUrl: tempUrl,
            storagePath: storagePath,
          );

          if (permanentUrl != null) {
            // Add image message with permanent URL
            final imageMessage = MessageEntity(
              id: _uuid.v4(),
              content: 'Here\'s your photo! 📸',
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              messageType: MessageType.image,
              imageUrl: permanentUrl,
            );
            state = state.copyWith(
              messages: [...messagesWithoutLoading, imageMessage],
              isSelfieLoading: false,
            );
            // Save image message to Firestore
            await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(imageMessage));
          } else {
            // Fallback to temporary URL
            final imageMessage = MessageEntity(
              id: _uuid.v4(),
              content: 'Here\'s your photo! 📸',
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              messageType: MessageType.image,
              imageUrl: tempUrl,
            );
            state = state.copyWith(
              messages: [...messagesWithoutLoading, imageMessage],
              isSelfieLoading: false,
            );
            await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(imageMessage));
          }
        } else {
          final errorMessage = MessageEntity(
            id: _uuid.v4(),
            content: 'Couldn\'t get the photo 😢 Try again!',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            isError: true,
          );
          state = state.copyWith(
            messages: [...messagesWithoutLoading, errorMessage],
            isSelfieLoading: false,
          );
          await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(errorMessage));
        }
      },
    );
    } catch (e, stackTrace) {
      print('❌ ChatController: Exception during photo generation: $e');
      print('❌ ChatController: Stack trace: $stackTrace');
      print('❌ ChatController: Exception type: ${e.runtimeType}');
      
      final messagesWithoutLoading = state.messages
          .where((m) => m.id != loadingMessageId)
          .toList();
      
      final errorMessage = MessageEntity(
        id: _uuid.v4(),
        content: 'Couldn\'t generate the photo right now 😅 Error: ${e.toString()}',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...messagesWithoutLoading, errorMessage],
        isSelfieLoading: false,
        error: e.toString(),
      );
      await _saveMessageToFirestore(conversationId, MessageModel.fromEntity(errorMessage));
    }
  }

  /// Save message to Firestore
  Future<void> _saveMessageToFirestore(String conversationId, MessageModel message) async {
    print('🔵 ChatController: _saveMessageToFirestore called for conversationId: $conversationId, messageId: ${message.id}');
    print('🔵 ChatController: Message type: ${message.messageType.name}, role: ${message.role.name}');
    print('🔵 ChatController: Message content: "${message.content.substring(0, message.content.length > 50 ? 50 : message.content.length)}${message.content.length > 50 ? "..." : ""}"');
    
    try {
      // CRITICAL: Ensure message has userId for Firestore security rules
      // Get userId from currentUserProvider or FirebaseAuth
      String? messageUserId = message.userId;
      if (messageUserId == null || messageUserId.isEmpty) {
        print('🔵 ChatController: Message userId is null, getting from FirebaseAuth...');
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          messageUserId = currentUser.uid;
          print('🔵 ChatController: Got userId from FirebaseAuth: $messageUserId');
        } else {
          print('❌ ChatController: No authenticated user found!');
          throw Exception('User not authenticated');
        }
      }
      
      // Create message with userId
      final messageWithUserId = MessageModel(
        id: message.id,
        content: message.content,
        role: message.role,
        timestamp: message.timestamp,
        isError: message.isError,
        tokensUsed: message.tokensUsed,
        messageType: message.messageType,
        imageUrl: message.imageUrl,
        userId: messageUserId,
      );
      
      print('🔵 ChatController: Saving message to Firestore at conversations/$conversationId/messages/${message.id}');
      print('🔵 ChatController: Message userId: ${messageWithUserId.userId}');
      
      // Use MessageModel.toFirestore() to ensure all fields including userId are included
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(message.id)
          .set(messageWithUserId.toFirestore());
      print('✅ ChatController: Message saved to Firestore successfully');

      // Update conversation's last message
      print('🔵 ChatController: Updating conversation last message...');
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': message.messageType == MessageType.image 
            ? '📸 Photo' 
            : message.content.length > 50 
                ? '${message.content.substring(0, 50)}...' 
                : message.content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ ChatController: Conversation updated successfully');
    } catch (e, stackTrace) {
      print('❌ ChatController: Error saving message to Firestore: $e');
      print('Stack trace: $stackTrace');
    }
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
    getOrCreateConversationUseCase: ref.watch(getOrCreateConversationUseCaseProvider),
    generateImageUseCase: ref.watch(generateImageUseCaseProvider),
    storageService: ref.watch(storageServiceProvider),
    firestore: ref.watch(firestoreProvider),
  );
});
