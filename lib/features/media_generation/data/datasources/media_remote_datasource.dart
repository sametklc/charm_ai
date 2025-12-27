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

      print('🔵 MediaRemoteDataSource: Response received');
      print('🔵 MediaRemoteDataSource: Response statusCode: ${response.statusCode}');
      print('🔵 MediaRemoteDataSource: Response data type: ${response.data.runtimeType}');
      print('🔵 MediaRemoteDataSource: Response data: $response.data');
      
      if (response.statusCode == 200) {
        
        final mediaId = _uuid.v4();
        
        // Ensure response.data is a Map
        Map<String, dynamic> responseData;
        try {
          if (response.data is Map<String, dynamic>) {
            responseData = response.data as Map<String, dynamic>;
            print('🔵 MediaRemoteDataSource: Response is Map<String, dynamic>');
          } else if (response.data is Map) {
            responseData = Map<String, dynamic>.from(response.data as Map);
            print('🔵 MediaRemoteDataSource: Response is Map, converted to Map<String, dynamic>');
          } else if (response.data is List) {
            responseData = {'images': response.data};
            print('🔵 MediaRemoteDataSource: Response is List, wrapped in Map');
          } else if (response.data is String) {
            responseData = {'images': [response.data]};
            print('🔵 MediaRemoteDataSource: Response is String, wrapped in Map');
          } else {
            print('⚠️ MediaRemoteDataSource: Unknown response type, creating default Map');
            responseData = {'images': response.data};
          }
        } catch (e, stackTrace) {
          print('❌ MediaRemoteDataSource: Error processing response.data: $e');
          print('❌ MediaRemoteDataSource: Stack trace: $stackTrace');
          print('❌ MediaRemoteDataSource: response.data type: ${response.data.runtimeType}');
          print('❌ MediaRemoteDataSource: response.data value: $response.data');
          rethrow;
        }
        
        print('🔵 MediaRemoteDataSource: Processed responseData: $responseData');
        print('🔵 MediaRemoteDataSource: Calling GeneratedMediaModel.fromApiResponse...');
        
        try {
          final media = GeneratedMediaModel.fromApiResponse(
            id: mediaId,
            userId: userId,
            json: responseData,
            prompt: params.prompt,
            model: params.model,
            width: params.width,
            height: params.height,
          );
          print('✅ MediaRemoteDataSource: GeneratedMediaModel created successfully');
          print('✅ MediaRemoteDataSource: Media imageUrls: ${media.imageUrls}');

          // Auto-save to Firestore (optional - don't fail if this fails)
          try {
            print('🔵 MediaRemoteDataSource: Attempting to save media to Firestore...');
            await saveMedia(media);
            print('✅ MediaRemoteDataSource: Media saved to Firestore successfully');
          } catch (e) {
            print('⚠️ MediaRemoteDataSource: Failed to save media to Firestore (non-critical): $e');
            // Continue anyway - media saving is optional
          }

          return media;
        } catch (e, stackTrace) {
          print('❌ MediaRemoteDataSource: Error in GeneratedMediaModel.fromApiResponse: $e');
          print('❌ MediaRemoteDataSource: Stack trace: $stackTrace');
          print('❌ MediaRemoteDataSource: responseData that caused error: $responseData');
          rethrow;
        }
      } else {
        print('❌ MediaRemoteDataSource: Non-200 status code: ${response.statusCode}');
        print('❌ MediaRemoteDataSource: Response data type: ${response.data?.runtimeType}');
        print('❌ MediaRemoteDataSource: Response data: ${response.data}');
        
        String errorMessage = 'Failed to generate image';
        try {
          if (response.data != null) {
            if (response.data is Map) {
              errorMessage = response.data['detail']?.toString() ?? 
                           response.data['message']?.toString() ?? 
                           'Failed to generate image';
            } else if (response.data is String) {
              errorMessage = response.data as String;
            } else {
              errorMessage = response.data.toString();
            }
          }
        } catch (e) {
          print('❌ MediaRemoteDataSource: Error parsing error response: $e');
          errorMessage = 'Failed to generate image';
        }
        
        throw ServerException(
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      print('❌ MediaRemoteDataSource: DioException caught');
      print('❌ MediaRemoteDataSource: DioException type: ${e.type}');
      print('❌ MediaRemoteDataSource: DioException message: ${e.message}');
      print('❌ MediaRemoteDataSource: Response statusCode: ${e.response?.statusCode}');
      print('❌ MediaRemoteDataSource: Response data type: ${e.response?.data?.runtimeType}');
      print('❌ MediaRemoteDataSource: Response data: ${e.response?.data}');
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException(message: 'Request timed out. Image generation may take a while, please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(message: 'No internet connection');
      }
      
      // Safely extract error message
      String errorMessage = 'Failed to generate image';
      try {
        if (e.response?.data != null) {
          final responseData = e.response!.data;
          print('🔵 MediaRemoteDataSource: Processing error response data: $responseData');
          
          if (responseData is Map) {
            errorMessage = responseData['detail']?.toString() ?? 
                         responseData['message']?.toString() ?? 
                         responseData.toString();
          } else if (responseData is String) {
            errorMessage = responseData;
          } else {
            errorMessage = responseData.toString();
          }
        }
      } catch (parseError) {
        print('❌ MediaRemoteDataSource: Error parsing error response: $parseError');
        errorMessage = e.message ?? 'Failed to generate image';
      }
      
      print('❌ MediaRemoteDataSource: Final error message: $errorMessage');
      throw AIGenerationException(
        message: errorMessage,
        modelName: params.model,
      );
    } catch (e, stackTrace) {
      print('❌ MediaRemoteDataSource: Unexpected error in generateImage: $e');
      print('❌ MediaRemoteDataSource: Stack trace: $stackTrace');
      print('❌ MediaRemoteDataSource: Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<void> saveMedia(GeneratedMediaModel media) async {
    print('🔵 MediaRemoteDataSource: saveMedia called for mediaId: ${media.id}');
    try {
      final firestoreData = media.toFirestore();
      print('🔵 MediaRemoteDataSource: Firestore data prepared: ${firestoreData.keys.join(", ")}');
      await _mediaCollection.doc(media.id).set(firestoreData);
      print('✅ MediaRemoteDataSource: Media saved to Firestore successfully');
    } catch (e, stackTrace) {
      print('❌ MediaRemoteDataSource: Error saving media: $e');
      print('Stack trace: $stackTrace');
      throw ServerException(message: 'Failed to save media: $e');
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

