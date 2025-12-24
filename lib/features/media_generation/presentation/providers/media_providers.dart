import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../data/datasources/media_remote_datasource.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/usecases/generate_image_usecase.dart';

// ============================================
// DATA SOURCES
// ============================================

final mediaRemoteDataSourceProvider = Provider<MediaRemoteDataSource>((ref) {
  return MediaRemoteDataSourceImpl(
    dio: ref.watch(dioProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

// ============================================
// REPOSITORIES
// ============================================

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepositoryImpl(
    remoteDataSource: ref.watch(mediaRemoteDataSourceProvider),
  );
});

// ============================================
// USE CASES
// ============================================

final generateImageUseCaseProvider = Provider<GenerateImageUseCase>((ref) {
  return GenerateImageUseCase(ref.watch(mediaRepositoryProvider));
});

final getModelsUseCaseProvider = Provider<GetModelsUseCase>((ref) {
  return GetModelsUseCase(ref.watch(mediaRepositoryProvider));
});

final getUserMediaUseCaseProvider = Provider<GetUserMediaUseCase>((ref) {
  return GetUserMediaUseCase(ref.watch(mediaRepositoryProvider));
});

final deleteMediaUseCaseProvider = Provider<DeleteMediaUseCase>((ref) {
  return DeleteMediaUseCase(ref.watch(mediaRepositoryProvider));
});

final toggleFavoriteUseCaseProvider = Provider<ToggleFavoriteUseCase>((ref) {
  return ToggleFavoriteUseCase(ref.watch(mediaRepositoryProvider));
});

// ============================================
// STATE PROVIDERS
// ============================================

/// Available AI models
final availableModelsProvider = FutureProvider<List<AIModel>>((ref) async {
  final getModels = ref.watch(getModelsUseCaseProvider);
  final result = await getModels();
  
  return result.fold(
    (failure) => [
      // Fallback models if API fails
      const AIModel(id: 'flux-schnell', name: 'Flux Schnell', description: 'Fast, high-quality', speed: 'fast'),
      const AIModel(id: 'flux-dev', name: 'Flux Dev', description: 'Higher quality', speed: 'medium'),
      const AIModel(id: 'sdxl', name: 'SDXL', description: 'Stable Diffusion XL', speed: 'medium'),
    ],
    (models) => models,
  );
});

/// User's generated media history
final userMediaHistoryProvider = FutureProvider<List<GeneratedMediaEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final getUserMedia = ref.watch(getUserMediaUseCaseProvider);
  final result = await getUserMedia(user.uid);

  return result.fold(
    (failure) => [],
    (media) => media,
  );
});

/// Selected model for generation
final selectedModelProvider = StateProvider<String>((ref) => 'flux-schnell');

/// Current aspect ratio selection
final selectedAspectRatioProvider = StateProvider<String>((ref) => '1:1');

