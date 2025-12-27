import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/media_entity.dart';

/// Media Repository Interface
abstract class MediaRepository {
  /// Get available AI models
  Future<Either<Failure, List<AIModel>>> getAvailableModels();

  /// Generate image(s)
  Future<Either<Failure, GeneratedMediaEntity>> generateImage({
    required String userId,
    required ImageGenerationParams params,
  });

  /// Save generated media to Firestore
  Future<Either<Failure, void>> saveMedia(GeneratedMediaEntity media);

  /// Get user's generated media history
  Future<Either<Failure, List<GeneratedMediaEntity>>> getUserMedia(String userId);

  /// Delete generated media
  Future<Either<Failure, void>> deleteMedia(String mediaId);

  /// Toggle favorite status
  Future<Either<Failure, void>> toggleFavorite(String mediaId, bool isFavorite);

  /// Get user's favorite media
  Future<Either<Failure, List<GeneratedMediaEntity>>> getFavoriteMedia(String userId);
}



