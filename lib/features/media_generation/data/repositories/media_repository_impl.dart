import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_remote_datasource.dart';
import '../models/media_model.dart';

/// Implementation of Media Repository
class MediaRepositoryImpl implements MediaRepository {
  final MediaRemoteDataSource remoteDataSource;

  MediaRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<AIModel>>> getAvailableModels() async {
    try {
      final models = await remoteDataSource.getAvailableModels();
      return Right(models);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get models'));
    }
  }

  @override
  Future<Either<Failure, GeneratedMediaEntity>> generateImage({
    required String userId,
    required ImageGenerationParams params,
  }) async {
    try {
      final media = await remoteDataSource.generateImage(
        userId: userId,
        params: params,
      );
      return Right(media.toEntity());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.statusCode));
    } on AIGenerationException catch (e) {
      return Left(AIGenerationFailure(message: e.message, modelName: e.modelName));
    } catch (e) {
      return Left(ServerFailure(message: 'Image generation failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> saveMedia(GeneratedMediaEntity media) async {
    try {
      await remoteDataSource.saveMedia(GeneratedMediaModel.fromEntity(media));
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save media'));
    }
  }

  @override
  Future<Either<Failure, List<GeneratedMediaEntity>>> getUserMedia(String userId) async {
    try {
      final mediaList = await remoteDataSource.getUserMedia(userId);
      return Right(mediaList.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get media history'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMedia(String mediaId) async {
    try {
      await remoteDataSource.deleteMedia(mediaId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete media'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFavorite(String mediaId, bool isFavorite) async {
    try {
      await remoteDataSource.toggleFavorite(mediaId, isFavorite);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update favorite'));
    }
  }

  @override
  Future<Either<Failure, List<GeneratedMediaEntity>>> getFavoriteMedia(String userId) async {
    try {
      final allMedia = await remoteDataSource.getUserMedia(userId);
      final favorites = allMedia.where((m) => m.isFavorite).toList();
      return Right(favorites.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get favorites'));
    }
  }
}



