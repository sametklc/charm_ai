import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
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
    logPrint: (obj) => print('DIO: $obj'),
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

// ============================================
// STATE PROVIDERS
// ============================================

/// Current conversation provider
final currentConversationProvider = StateProvider<ConversationEntity?>((ref) => null);

/// Current character ID for chat
final currentChatCharacterIdProvider = StateProvider<String?>((ref) => null);

/// User conversations list provider
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

