import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/usecases/generate_image_usecase.dart';
import 'media_providers.dart';

/// Media generation state
class MediaGenerationState {
  final GenerationStatus status;
  final GeneratedMediaEntity? currentMedia;
  final List<GeneratedMediaEntity> history;
  final String? error;
  final double progress;

  const MediaGenerationState({
    this.status = GenerationStatus.idle,
    this.currentMedia,
    this.history = const [],
    this.error,
    this.progress = 0.0,
  });

  MediaGenerationState copyWith({
    GenerationStatus? status,
    GeneratedMediaEntity? currentMedia,
    List<GeneratedMediaEntity>? history,
    String? error,
    double? progress,
  }) {
    return MediaGenerationState(
      status: status ?? this.status,
      currentMedia: currentMedia ?? this.currentMedia,
      history: history ?? this.history,
      error: error,
      progress: progress ?? this.progress,
    );
  }

  bool get isGenerating => status == GenerationStatus.generating;
  bool get hasError => status == GenerationStatus.error;
  bool get hasResult => status == GenerationStatus.success && currentMedia != null;
}

/// Media Generation Controller
class MediaGenerationController extends StateNotifier<MediaGenerationState> {
  final GenerateImageUseCase _generateImageUseCase;
  final GetUserMediaUseCase _getUserMediaUseCase;
  final DeleteMediaUseCase _deleteMediaUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase;

  MediaGenerationController({
    required GenerateImageUseCase generateImageUseCase,
    required GetUserMediaUseCase getUserMediaUseCase,
    required DeleteMediaUseCase deleteMediaUseCase,
    required ToggleFavoriteUseCase toggleFavoriteUseCase,
  })  : _generateImageUseCase = generateImageUseCase,
        _getUserMediaUseCase = getUserMediaUseCase,
        _deleteMediaUseCase = deleteMediaUseCase,
        _toggleFavoriteUseCase = toggleFavoriteUseCase,
        super(const MediaGenerationState());

  /// Generate image with given parameters
  Future<void> generateImage({
    required String userId,
    required String prompt,
    String? negativePrompt,
    String model = 'flux-schnell',
    int width = 1024,
    int height = 1024,
    int numOutputs = 1,
  }) async {
    if (prompt.trim().isEmpty) {
      state = state.copyWith(
        status: GenerationStatus.error,
        error: 'Please enter a prompt',
      );
      return;
    }

    state = state.copyWith(
      status: GenerationStatus.generating,
      error: null,
      progress: 0.0,
    );

    // Simulate progress (since we don't have real progress from API)
    _simulateProgress();

    final params = ImageGenerationParams(
      prompt: prompt,
      negativePrompt: negativePrompt,
      model: model,
      width: width,
      height: height,
      numOutputs: numOutputs,
    );

    final result = await _generateImageUseCase(
      userId: userId,
      params: params,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          status: GenerationStatus.error,
          error: failure.message,
          progress: 0.0,
        );
      },
      (media) {
        state = state.copyWith(
          status: GenerationStatus.success,
          currentMedia: media,
          history: [media, ...state.history],
          progress: 1.0,
        );
      },
    );
  }

  /// Load user's media history
  Future<void> loadHistory(String userId) async {
    final result = await _getUserMediaUseCase(userId);

    result.fold(
      (failure) {
        // Silent fail for history loading
      },
      (media) {
        state = state.copyWith(history: media);
      },
    );
  }

  /// Delete media
  Future<bool> deleteMedia(String mediaId) async {
    final result = await _deleteMediaUseCase(mediaId);

    return result.fold(
      (failure) => false,
      (_) {
        state = state.copyWith(
          history: state.history.where((m) => m.id != mediaId).toList(),
          currentMedia: state.currentMedia?.id == mediaId ? null : state.currentMedia,
        );
        return true;
      },
    );
  }

  /// Toggle favorite
  Future<bool> toggleFavorite(String mediaId) async {
    final media = state.history.firstWhere(
      (m) => m.id == mediaId,
      orElse: () => state.currentMedia!,
    );

    final newFavoriteStatus = !media.isFavorite;
    final result = await _toggleFavoriteUseCase(mediaId, newFavoriteStatus);

    return result.fold(
      (failure) => false,
      (_) {
        // Update in history
        final updatedHistory = state.history.map((m) {
          if (m.id == mediaId) {
            return m.copyWith(isFavorite: newFavoriteStatus);
          }
          return m;
        }).toList();

        // Update current media if it's the same
        GeneratedMediaEntity? updatedCurrent = state.currentMedia;
        if (state.currentMedia?.id == mediaId) {
          updatedCurrent = state.currentMedia!.copyWith(isFavorite: newFavoriteStatus);
        }

        state = state.copyWith(
          history: updatedHistory,
          currentMedia: updatedCurrent,
        );
        return true;
      },
    );
  }

  /// Reset to initial state
  void reset() {
    state = state.copyWith(
      status: GenerationStatus.idle,
      currentMedia: null,
      error: null,
      progress: 0.0,
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Simulate progress animation
  void _simulateProgress() async {
    for (int i = 1; i <= 90; i += 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (state.status == GenerationStatus.generating) {
        state = state.copyWith(progress: i / 100);
      }
    }
  }
}

/// Media Generation Controller Provider
final mediaGenerationControllerProvider =
    StateNotifierProvider<MediaGenerationController, MediaGenerationState>((ref) {
  return MediaGenerationController(
    generateImageUseCase: ref.watch(generateImageUseCaseProvider),
    getUserMediaUseCase: ref.watch(getUserMediaUseCaseProvider),
    deleteMediaUseCase: ref.watch(deleteMediaUseCaseProvider),
    toggleFavoriteUseCase: ref.watch(toggleFavoriteUseCaseProvider),
  );
});

