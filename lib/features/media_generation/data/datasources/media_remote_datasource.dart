import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/media_entity.dart';
import '../models/media_model.dart';

/// Media Remote Data Source Interface
abstract class MediaRemoteDataSource {
  /// Get available AI models from backend
  Future<List<AIModelModel>> getAvailableModels();

  /// Generate image(s) via backend
  Future<GeneratedMediaModel> generateImage({
    required String userId,
    required ImageGenerationParams params,
  });

  /// Save media to Firestore
  Future<void> saveMedia(GeneratedMediaModel media);

  /// Get user's media from Firestore
  Future<List<GeneratedMediaModel>> getUserMedia(String userId);

  /// Delete media from Firestore
  Future<void> deleteMedia(String mediaId);

  /// Update favorite status
  Future<void> toggleFavorite(String mediaId, bool isFavorite);
}

/// Implementation of Media Remote Data Source
class MediaRemoteDataSourceImpl implements MediaRemoteDataSource {
  final Dio _dio;
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  MediaRemoteDataSourceImpl({
    required Dio dio,
    required FirebaseFirestore firestore,
  })  : _dio = dio,
        _firestore = firestore;

  CollectionReference get _mediaCollection =>
      _firestore.collection(AppConstants.mediaCollection);

  @override
  Future<List<AIModelModel>> getAvailableModels() async {
    try {
      final response = await _dio.get('${ApiConstants.generateImage.replaceAll('/image', '')}/models');

      if (response.statusCode == 200) {
        final models = response.data['models'] as List<dynamic>;
        return models.map((m) => AIModelModel.fromJson(m)).toList();
      } else {
        throw ServerException(message: 'Failed to get models');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(message: 'No internet connection');
      }
      throw ServerException(
        message: e.response?.data?['detail'] ?? 'Failed to get models',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<GeneratedMediaModel> generateImage({
    required String userId,
    required ImageGenerationParams params,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.generateImage,
        data: params.toJson(),
        options: Options(
          receiveTimeout: const Duration(minutes: 5), // Image gen can take time
        ),
      );

      if (response.statusCode == 200) {
        final mediaId = _uuid.v4();
        final media = GeneratedMediaModel.fromApiResponse(
          id: mediaId,
          userId: userId,
          json: response.data,
          prompt: params.prompt,
          model: params.model,
          width: params.width,
          height: params.height,
        );

        // Auto-save to Firestore
        await saveMedia(media);

        return media;
      } else {
        throw ServerException(
          message: response.data?['detail'] ?? 'Failed to generate image',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException(message: 'Request timed out. Image generation may take a while, please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(message: 'No internet connection');
      }
      throw AIGenerationException(
        message: e.response?.data?['detail'] ?? 'Failed to generate image',
        modelName: params.model,
      );
    }
  }

  @override
  Future<void> saveMedia(GeneratedMediaModel media) async {
    try {
      await _mediaCollection.doc(media.id).set(media.toFirestore());
    } catch (e) {
      throw ServerException(message: 'Failed to save media');
    }
  }

  @override
  Future<List<GeneratedMediaModel>> getUserMedia(String userId) async {
    try {
      final query = await _mediaCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return query.docs
          .map((doc) => GeneratedMediaModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get media history');
    }
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    try {
      await _mediaCollection.doc(mediaId).delete();
    } catch (e) {
      throw ServerException(message: 'Failed to delete media');
    }
  }

  @override
  Future<void> toggleFavorite(String mediaId, bool isFavorite) async {
    try {
      await _mediaCollection.doc(mediaId).update({
        'isFavorite': isFavorite,
      });
    } catch (e) {
      throw ServerException(message: 'Failed to update favorite');
    }
  }
}

