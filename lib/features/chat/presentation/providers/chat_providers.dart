import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/conversation_usecases.dart';
import '../../domain/usecases/send_message_usecase.dart';

// ============================================
// DIO CLIENT
// ============================================

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectionTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add logging interceptor for debug
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (obj) {}, // Disabled in production
  ));

  return dio;
});

// ============================================
// DATA SOURCES
// ============================================

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl(
    dio: ref.watch(dioProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

// ============================================
// REPOSITORIES
// ============================================

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    remoteDataSource: ref.watch(chatRemoteDataSourceProvider),
  );
});

// ============================================
// USE CASES
// ============================================

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(ref.watch(chatRepositoryProvider));
});

final sendMessageStreamUseCaseProvider = Provider<SendMessageStreamUseCase>((ref) {
  return SendMessageStreamUseCase(ref.watch(chatRepositoryProvider));
});

final createConversationUseCaseProvider = Provider<CreateConversationUseCase>((ref) {
  return CreateConversationUseCase(ref.watch(chatRepositoryProvider));
});

final getConversationsUseCaseProvider = Provider<GetConversationsUseCase>((ref) {
  return GetConversationsUseCase(ref.watch(chatRepositoryProvider));
});

final getCharacterConversationsUseCaseProvider = Provider<GetCharacterConversationsUseCase>((ref) {
  return GetCharacterConversationsUseCase(ref.watch(chatRepositoryProvider));
});

final deleteConversationUseCaseProvider = Provider<DeleteConversationUseCase>((ref) {
  return DeleteConversationUseCase(ref.watch(chatRepositoryProvider));
});

final deleteAllConversationsUseCaseProvider = Provider<DeleteAllConversationsUseCase>((ref) {
  return DeleteAllConversationsUseCase(ref.watch(chatRepositoryProvider));
});

final getOrCreateConversationUseCaseProvider = Provider<GetOrCreateConversationUseCase>((ref) {
  return GetOrCreateConversationUseCase(ref.watch(chatRepositoryProvider));
});

// ============================================
// STATE PROVIDERS
// ============================================

/// Current conversation provider
final currentConversationProvider = StateProvider<ConversationEntity?>((ref) => null);

/// Current character ID for chat
final currentChatCharacterIdProvider = StateProvider<String?>((ref) => null);

/// User conversations list provider (Future-based)
final userConversationsProvider = FutureProvider<List<ConversationEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final getConversations = ref.watch(getConversationsUseCaseProvider);
  final result = await getConversations(user.uid);

  return result.fold(
    (failure) => [],
    (conversations) => conversations,
  );
});

/// Conversations for a specific character
final characterConversationsProvider = FutureProvider.family<List<ConversationEntity>, String>((ref, characterId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final getCharacterConversations = ref.watch(getCharacterConversationsUseCaseProvider);
  final result = await getCharacterConversations(
    userId: user.uid,
    characterId: characterId,
  );

  return result.fold(
    (failure) => [],
    (conversations) => conversations,
  );
});

// ============================================
// STREAM PROVIDERS (Real-time)
// ============================================

/// Real-time stream of user's conversations (for chat history screen)
final conversationsStreamProvider = StreamProvider<List<ConversationEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    print('ConversationsStream: User is null, returning empty list');
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreProvider);
  
  print('ConversationsStream: Starting stream for user ${user.uid}');
  
  try {
    return firestore
        .collection('conversations')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          print('ConversationsStream: Received ${snapshot.docs.length} conversations');
          
          try {
            final conversations = <ConversationEntity>[];
            
            for (var doc in snapshot.docs) {
              try {
                final conversation = ConversationModel.fromFirestore(doc).toEntity();
                conversations.add(conversation);
                print('ConversationsStream: Parsed conversation ${doc.id}: ${conversation.characterId}');
              } catch (e, stackTrace) {
                print('ConversationsStream: Error parsing conversation ${doc.id}: $e');
                print('Stack trace: $stackTrace');
                // Continue with next conversation
              }
            }
            
            // Remove duplicates by characterId (keep only the most recent conversation for each character)
            final uniqueConversations = <String, ConversationEntity>{};
            for (final conversation in conversations) {
              final existing = uniqueConversations[conversation.characterId];
              if (existing == null) {
                uniqueConversations[conversation.characterId] = conversation;
              } else {
                // Keep the more recent one
                final existingTime = existing.lastMessageTimestamp ?? existing.updatedAt;
                final currentTime = conversation.lastMessageTimestamp ?? conversation.updatedAt;
                if (currentTime.isAfter(existingTime)) {
                  uniqueConversations[conversation.characterId] = conversation;
                }
              }
            }

            final deduplicatedConversations = uniqueConversations.values.toList();

            // Sort by lastMessageTimestamp descending (most recent first)
            // Fall back to updatedAt if lastMessageTimestamp is null
            deduplicatedConversations.sort((a, b) {
              final aTime = a.lastMessageTimestamp ?? a.updatedAt;
              final bTime = b.lastMessageTimestamp ?? b.updatedAt;
              return bTime.compareTo(aTime);
            });

            print('ConversationsStream: Returning ${deduplicatedConversations.length} deduplicated conversations (from ${conversations.length} total)');
            return deduplicatedConversations;
          } catch (e, stackTrace) {
            print('ConversationsStream: Error parsing conversations list: $e');
            print('Stack trace: $stackTrace');
            return <ConversationEntity>[];
          }
        }).handleError((error, stackTrace) {
          print('ConversationsStream: Error in stream: $error');
          print('Stack trace: $stackTrace');
          return <ConversationEntity>[];
        });
  } catch (e, stackTrace) {
    print('ConversationsStream: Error creating stream: $e');
    print('Stack trace: $stackTrace');
    return Stream.value(<ConversationEntity>[]);
  }
});

/// Real-time stream of messages for a specific conversation
final messagesStreamProvider = StreamProvider.family<List<MessageEntity>, String>((ref, conversationId) {
  print('🔵 messagesStreamProvider: Starting stream for conversationId: $conversationId');
  
  if (conversationId.isEmpty) {
    print('⚠️ messagesStreamProvider: conversationId is empty, returning empty stream');
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreProvider);
  
  print('🔵 messagesStreamProvider: Setting up Firestore stream for conversations/$conversationId/messages');
  
  return firestore
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) {
        print('🔵 messagesStreamProvider: Received snapshot with ${snapshot.docs.length} messages for conversationId: $conversationId');
        final messages = snapshot.docs.map((doc) {
          print('🔵 messagesStreamProvider: Parsing message ${doc.id}');
          return MessageModel.fromFirestore(doc.data(), doc.id).toEntity();
        }).toList();
        print('✅ messagesStreamProvider: Returning ${messages.length} messages for conversationId: $conversationId');
        return messages;
      })
      .handleError((error, stackTrace) {
        print('❌ messagesStreamProvider: Error in stream for conversationId $conversationId: $error');
        print('Stack trace: $stackTrace');
        return <MessageEntity>[];
      });
});
