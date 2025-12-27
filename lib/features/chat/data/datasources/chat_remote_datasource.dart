import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';

/// Chat Remote Data Source Interface
abstract class ChatRemoteDataSource {
  /// Send message to AI and get response
  /// [systemPrompt] is used for character personality
  Future<MessageModel> sendMessage({
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  });

  /// Send message and get streaming response
  /// [systemPrompt] is used for character personality
  Stream<String> sendMessageStream({
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  });

  /// Save conversation to Firestore
  Future<void> saveConversation(ConversationModel conversation);

  /// Get conversation from Firestore
  Future<ConversationModel?> getConversation(String conversationId);

  /// Get all conversations for user
  Future<List<ConversationModel>> getUserConversations(String userId);

  /// Get conversations for user with a specific character
  Future<List<ConversationModel>> getUserCharacterConversations(
    String userId,
    String characterId,
  );

  /// Delete conversation
  Future<void> deleteConversation(String conversationId);

  /// Delete all conversations for a user
  Future<void> deleteAllUserConversations(String userId);

  /// Save message to conversation
  Future<void> saveMessage(String conversationId, MessageModel message);

  /// Get messages for conversation
  Future<List<MessageModel>> getMessages(String conversationId);
}

/// Implementation of Chat Remote Data Source
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio _dio;
  final FirebaseFirestore _firestore;

  ChatRemoteDataSourceImpl({
    required Dio dio,
    required FirebaseFirestore firestore,
  })  : _dio = dio,
        _firestore = firestore;

  CollectionReference get _chatsCollection =>
      _firestore.collection(AppConstants.chatsCollection);

  @override
  Future<MessageModel> sendMessage({
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  }) async {
    try {
      // Prepare conversation history (excluding system messages)
      final messages = <Map<String, dynamic>>[];
      messages.addAll(
        history
            .where((m) => !m.isSystem) // Skip system messages
            .map((m) => MessageModel.fromEntity(m).toJson()),
      );
      messages.add({'role': 'user', 'content': message});

      // Build request body
      final requestBody = <String, dynamic>{
        'messages': messages,
        'max_tokens': 500, // Keep responses concise
        'temperature': 0.9, // Higher for more personality
      };
      
      // Add system prompt for character personality (sent separately to backend)
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        requestBody['system_prompt'] = systemPrompt;
      }

      // Call backend API
      final response = await _dio.post(
        ApiConstants.chat,
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return MessageModel.assistant(
          content: data['message'] ?? '',
          tokensUsed: data['tokens_used'],
        );
      } else {
        throw ServerException(
          message: response.data?['detail'] ?? 'Failed to get AI response',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException(message: 'Connection timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(message: 'No internet connection');
      }
      throw ServerException(
        message: e.response?.data?['detail'] ?? 'Failed to send message',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Stream<String> sendMessageStream({
    required String message,
    required List<MessageEntity> history,
    String? systemPrompt,
  }) async* {
    try {
      // Prepare conversation history (excluding system messages)
      final messages = <Map<String, dynamic>>[];
      messages.addAll(
        history
            .where((m) => !m.isSystem) // Skip system messages
            .map((m) => MessageModel.fromEntity(m).toJson()),
      );
      messages.add({'role': 'user', 'content': message});

      // Build request body
      final requestBody = <String, dynamic>{
        'messages': messages,
        'max_tokens': 500, // Keep responses concise
        'temperature': 0.9, // Higher for more personality
      };
      
      // Add system prompt for character personality
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        requestBody['system_prompt'] = systemPrompt;
      }

      // Call streaming endpoint
      final response = await _dio.post(
        '${ApiConstants.chat}/stream',
        data: requestBody,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        
        // Process SSE data
        final lines = buffer.split('\n');
        buffer = lines.last; // Keep incomplete line in buffer
        
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final data = json.decode(jsonStr);
              if (data['content'] != null && data['content'].isNotEmpty) {
                yield data['content'];
              }
              if (data['is_complete'] == true) {
                return;
              }
              if (data['error'] != null) {
                throw AIGenerationException(message: data['error']);
              }
            } catch (e) {
              if (e is AIGenerationException) rethrow;
              // Skip invalid JSON
            }
          }
        }
      }
    } on DioException catch (e) {
      throw ServerException(
        message: 'Streaming failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> saveConversation(ConversationModel conversation) async {
    print('🔵 ChatRemoteDataSource: saveConversation called for conversationId: ${conversation.id}');
    print('🔵 ChatRemoteDataSource: userId: ${conversation.userId}, characterId: ${conversation.characterId}');
    
    try {
      final firestoreData = conversation.toFirestore();
      print('🔵 ChatRemoteDataSource: Firestore data prepared: ${firestoreData.keys.join(", ")}');
      
      await _chatsCollection.doc(conversation.id).set(
        firestoreData,
        SetOptions(merge: true),
      );
      print('✅ ChatRemoteDataSource: Conversation saved successfully to Firestore');
    } catch (e, stackTrace) {
      print('❌ ChatRemoteDataSource: Error saving conversation: $e');
      print('Stack trace: $stackTrace');
      throw ServerException(message: 'Failed to save conversation: $e');
    }
  }

  @override
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _chatsCollection.doc(conversationId).get();
      if (!doc.exists) return null;

      final conversation = ConversationModel.fromFirestore(doc);
      final messages = await getMessages(conversationId);

      return conversation.copyWith(messages: messages);
    } catch (e) {
      throw ServerException(message: 'Failed to get conversation');
    }
  }

  @override
  Future<List<ConversationModel>> getUserConversations(String userId) async {
    try {
      final query = await _chatsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      return query.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get conversations');
    }
  }

  @override
  Future<List<ConversationModel>> getUserCharacterConversations(
    String userId,
    String characterId,
  ) async {
    print('🔵 ChatRemoteDataSource: getUserCharacterConversations called');
    print('🔵 ChatRemoteDataSource: userId: $userId, characterId: $characterId');
    
    try {
      final query = await _chatsCollection
          .where('userId', isEqualTo: userId)
          .where('characterId', isEqualTo: characterId)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      print('✅ ChatRemoteDataSource: Query returned ${query.docs.length} conversations');
      
      final conversations = query.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();
      
      for (final conv in conversations) {
        print('  - ${conv.id}: ${conv.characterId} (${conv.characterName})');
      }
      
      return conversations;
    } catch (e, stackTrace) {
      print('❌ ChatRemoteDataSource: Error getting character conversations: $e');
      print('Stack trace: $stackTrace');
      throw ServerException(message: 'Failed to get character conversations: $e');
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      print('🔵 ChatRemoteDataSource: deleteConversation called for conversationId: $conversationId');
      
      // Delete all messages first (one by one to ensure deletion)
      final messagesQuery = await _chatsCollection
          .doc(conversationId)
          .collection(AppConstants.messagesCollection)
          .get();

      print('🔵 ChatRemoteDataSource: Found ${messagesQuery.docs.length} messages to delete');

      // Delete messages one by one
      for (final doc in messagesQuery.docs) {
        print('🔵 ChatRemoteDataSource: Deleting message ${doc.id}...');
        await doc.reference.delete();
        print('✅ ChatRemoteDataSource: Message ${doc.id} deleted');
      }
      
      // Delete the conversation document
      print('🔵 ChatRemoteDataSource: Deleting conversation $conversationId...');
      await _chatsCollection.doc(conversationId).delete();
      print('✅ ChatRemoteDataSource: Conversation $conversationId deleted successfully');
    } catch (e, stackTrace) {
      print('❌ ChatRemoteDataSource: Error deleting conversation: $e');
      print('Stack trace: $stackTrace');
      throw ServerException(message: 'Failed to delete conversation: $e');
    }
  }

  @override
  Future<void> deleteAllUserConversations(String userId) async {
    try {
      print('🔵 ChatRemoteDataSource: deleteAllUserConversations called for userId: $userId');
      
      // Get all conversations for the user
      final conversationsQuery = await _chatsCollection
          .where('userId', isEqualTo: userId)
          .get();
      
      print('🔵 ChatRemoteDataSource: Found ${conversationsQuery.docs.length} conversations to delete');
      
      if (conversationsQuery.docs.isEmpty) {
        print('✅ ChatRemoteDataSource: No conversations to delete');
        return;
      }
      
      // Delete each conversation and its messages one by one
      for (final convDoc in conversationsQuery.docs) {
        print('🔵 ChatRemoteDataSource: Processing conversation ${convDoc.id}...');
        
        // Delete all messages in this conversation
        final messagesQuery = await _chatsCollection
            .doc(convDoc.id)
            .collection(AppConstants.messagesCollection)
            .get();
        
        print('🔵 ChatRemoteDataSource: Found ${messagesQuery.docs.length} messages in conversation ${convDoc.id}');
        
        for (final msgDoc in messagesQuery.docs) {
          await msgDoc.reference.delete();
          print('✅ ChatRemoteDataSource: Deleted message ${msgDoc.id}');
        }
        
        // Delete the conversation
        await convDoc.reference.delete();
        print('✅ ChatRemoteDataSource: Deleted conversation ${convDoc.id}');
      }
      
      print('✅ ChatRemoteDataSource: All ${conversationsQuery.docs.length} conversations and their messages deleted successfully');
    } catch (e, stackTrace) {
      print('❌ ChatRemoteDataSource: Error deleting all conversations: $e');
      print('Stack trace: $stackTrace');
      throw ServerException(message: 'Failed to delete all conversations: $e');
    }
  }

  @override
  Future<void> saveMessage(String conversationId, MessageModel message) async {
    print('🔵 ChatRemoteDataSource: saveMessage called for conversationId: $conversationId, messageId: ${message.id}');
    print('🔵 ChatRemoteDataSource: Message type: ${message.messageType.name}, role: ${message.role.name}');
    print('🔵 ChatRemoteDataSource: Message content: "${message.content.substring(0, message.content.length > 100 ? 100 : message.content.length)}${message.content.length > 100 ? "..." : ""}"');
    
    try {
      // CRITICAL: Ensure message has userId for Firestore security rules
      // Get userId from FirebaseAuth directly (not from conversation to avoid permission issues)
      String? messageUserId = message.userId;
      if (messageUserId == null || messageUserId.isEmpty) {
        print('🔵 ChatRemoteDataSource: Message userId is null, getting from FirebaseAuth...');
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          messageUserId = currentUser.uid;
          print('🔵 ChatRemoteDataSource: Got userId from FirebaseAuth: $messageUserId');
        } else {
          print('❌ ChatRemoteDataSource: No authenticated user found!');
          throw ServerException(message: 'User not authenticated');
        }
      }
      
      // Create message with userId if it was missing
      final messageWithUserId = messageUserId != null && messageUserId.isNotEmpty
          ? MessageModel(
              id: message.id,
              content: message.content,
              role: message.role,
              timestamp: message.timestamp,
              isError: message.isError,
              tokensUsed: message.tokensUsed,
              messageType: message.messageType,
              imageUrl: message.imageUrl,
              userId: messageUserId,
            )
          : message;
      
      print('🔵 ChatRemoteDataSource: Saving message to Firestore at conversations/$conversationId/messages/${message.id}');
      print('🔵 ChatRemoteDataSource: Message userId: ${messageWithUserId.userId}');
      await _chatsCollection
          .doc(conversationId)
          .collection(AppConstants.messagesCollection)
          .doc(message.id)
          .set(messageWithUserId.toFirestore());
      print('✅ ChatRemoteDataSource: Message document saved to Firestore');

      // Update conversation's metadata for chat list display
      String lastMessageContent = message.content;
      if (message.isImage) {
        lastMessageContent = '📷 Photo';
      } else if (message.content.length > 50) {
        lastMessageContent = '${message.content.substring(0, 50)}...';
      }
      
      print('🔵 ChatRemoteDataSource: Updating conversation metadata...');
      await _chatsCollection.doc(conversationId).update({
        'updatedAt': Timestamp.now(),
        'lastMessage': lastMessageContent, // Use 'lastMessage' for consistency
        'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
      });
      print('✅ ChatRemoteDataSource: Conversation metadata updated');
    } catch (e, stackTrace) {
      print('❌ ChatRemoteDataSource: Error saving message: $e');
      print('Stack trace: $stackTrace');
      throw ServerException(message: 'Failed to save message: ${e.toString()}');
    }
  }

  @override
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final query = await _chatsCollection
          .doc(conversationId)
          .collection(AppConstants.messagesCollection)
          .orderBy('timestamp', descending: false)
          .get();

      return query.docs
          .map((doc) => MessageModel.fromFirestore(
                doc.data(),
                doc.id,
              ))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get messages');
    }
  }
}

