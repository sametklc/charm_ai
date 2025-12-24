import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';

/// Chat Remote Data Source Interface
abstract class ChatRemoteDataSource {
  /// Send message to AI and get response
  Future<MessageModel> sendMessage({
    required String message,
    required List<MessageEntity> history,
  });

  /// Send message and get streaming response
  Stream<String> sendMessageStream({
    required String message,
    required List<MessageEntity> history,
  });

  /// Save conversation to Firestore
  Future<void> saveConversation(ConversationModel conversation);

  /// Get conversation from Firestore
  Future<ConversationModel?> getConversation(String conversationId);

  /// Get all conversations for user
  Future<List<ConversationModel>> getUserConversations(String userId);

  /// Delete conversation
  Future<void> deleteConversation(String conversationId);

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
  }) async {
    try {
      // Prepare messages for API
      final messages = history.map((m) => MessageModel.fromEntity(m).toJson()).toList();
      messages.add({'role': 'user', 'content': message});

      // Call backend API
      final response = await _dio.post(
        ApiConstants.chat,
        data: {
          'messages': messages,
          'max_tokens': 1000,
          'temperature': 0.7,
        },
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
  }) async* {
    try {
      // Prepare messages for API
      final messages = history.map((m) => MessageModel.fromEntity(m).toJson()).toList();
      messages.add({'role': 'user', 'content': message});

      // Call streaming endpoint
      final response = await _dio.post(
        '${ApiConstants.chat}/stream',
        data: {
          'messages': messages,
          'max_tokens': 1000,
          'temperature': 0.7,
        },
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
    try {
      await _chatsCollection.doc(conversation.id).set(
        conversation.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw ServerException(message: 'Failed to save conversation');
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
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages first
      final messagesQuery = await _chatsCollection
          .doc(conversationId)
          .collection(AppConstants.messagesCollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_chatsCollection.doc(conversationId));
      await batch.commit();
    } catch (e) {
      throw ServerException(message: 'Failed to delete conversation');
    }
  }

  @override
  Future<void> saveMessage(String conversationId, MessageModel message) async {
    try {
      await _chatsCollection
          .doc(conversationId)
          .collection(AppConstants.messagesCollection)
          .doc(message.id)
          .set(message.toFirestore());

      // Update conversation's updatedAt
      await _chatsCollection.doc(conversationId).update({
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw ServerException(message: 'Failed to save message');
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

