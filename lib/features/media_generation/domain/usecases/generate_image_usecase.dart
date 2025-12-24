import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/media_entity.dart';
import '../repositories/media_repository.dart';

/// Use case for generating images
class GenerateImageUseCase {
  final MediaRepository repository;

  GenerateImageUseCase(this.repository);

  Future<Either<Failure, GeneratedMediaEntity>> call({
    required String userId,
    required ImageGenerationParams params,
  }) async {
    // Validate prompt
    if (params.prompt.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'Prompt cannot be empty'));
    }

    if (params.prompt.length > 2000) {
      return const Left(ValidationFailure(message: 'Prompt is too long (max 2000 characters)'));
    }

    // Validate dimensions
    if (params.width < 256 || params.width > 1440) {
      return const Left(ValidationFailure(message: 'Width must be between 256 and 1440'));
    }

    if (params.height < 256 || params.height > 1440) {
      return const Left(ValidationFailure(message: 'Height must be between 256 and 1440'));
    }

    return await repository.generateImage(
      userId: userId,
      params: params,
    );
  }
}

/// Use case for getting available models
class GetModelsUseCase {
  final MediaRepository repository;

  GetModelsUseCase(this.repository);

  Future<Either<Failure, List<AIModel>>> call() async {
    return await repository.getAvailableModels();
  }
}

/// Use case for getting user's media history
class GetUserMediaUseCase {
  final MediaRepository repository;

  GetUserMediaUseCase(this.repository);

  Future<Either<Failure, List<GeneratedMediaEntity>>> call(String userId) async {
    if (userId.isEmpty) {
      return const Left(ValidationFailure(message: 'User ID is required'));
    }
    return await repository.getUserMedia(userId);
  }
}

/// Use case for deleting media
class DeleteMediaUseCase {
  final MediaRepository repository;

  DeleteMediaUseCase(this.repository);

  Future<Either<Failure, void>> call(String mediaId) async {
    if (mediaId.isEmpty) {
      return const Left(ValidationFailure(message: 'Media ID is required'));
    }
    return await repository.deleteMedia(mediaId);
  }
}

/// Use case for toggling favorite
class ToggleFavoriteUseCase {
  final MediaRepository repository;

  ToggleFavoriteUseCase(this.repository);

  Future<Either<Failure, void>> call(String mediaId, bool isFavorite) async {
    if (mediaId.isEmpty) {
      return const Left(ValidationFailure(message: 'Media ID is required'));
    }
    return await repository.toggleFavorite(mediaId, isFavorite);
  }
}

