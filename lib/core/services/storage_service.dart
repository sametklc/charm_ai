import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Firebase Storage Service for persisting media
class StorageService {
  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Upload a file to Firebase Storage and get permanent URL
  Future<String?> uploadFile({
    required File file,
    required String path,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
      );

      final uploadTask = await ref.putFile(file, metadata);
      
      if (uploadTask.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      print('StorageService: Error uploading file: $e');
      return null;
    }
  }

  /// Upload bytes directly to Firebase Storage
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String path,
    String? contentType,
  }) async {
    try {
      print('StorageService: Starting upload to $path (${bytes.length} bytes)');
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );

      // Upload with timeout
      final uploadTask = ref.putData(
        bytes,
        metadata,
      );
      
      // Wait for upload to complete with timeout
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Upload timeout after 2 minutes');
        },
      );
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        print('StorageService: Upload successful. URL: $downloadUrl');
        return downloadUrl;
      } else {
        print('StorageService: Upload failed with state: ${snapshot.state}');
        return null;
      }
    } on FirebaseException catch (e) {
      print('StorageService: Firebase error uploading bytes: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('StorageService: Error uploading bytes: $e');
      print('StorageService: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Download image from URL and upload to Firebase Storage
  /// Returns the permanent Firebase Storage download URL
  Future<String?> downloadAndUpload({
    required String sourceUrl,
    required String storagePath,
  }) async {
    try {
      print('StorageService: Downloading image from $sourceUrl');
      
      // Download the image from the temporary URL with timeout
      final response = await http.get(Uri.parse(sourceUrl)).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Image download timeout');
        },
      );
      
      if (response.statusCode != 200) {
        print('StorageService: Failed to download image. Status code: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      
      if (bytes.isEmpty) {
        print('StorageService: Downloaded image is empty');
        return null;
      }
      
      print('StorageService: Downloaded ${bytes.length} bytes');

      // Determine content type
      String contentType = 'image/jpeg';
      final contentTypeHeader = response.headers['content-type'];
      if (contentTypeHeader != null) {
        contentType = contentTypeHeader;
      }

      print('StorageService: Uploading to Firebase Storage at $storagePath');
      
      // Upload to Firebase Storage
      final url = await uploadBytes(
        bytes: bytes,
        path: storagePath,
        contentType: contentType,
      );
      
      if (url != null) {
        print('StorageService: Successfully uploaded. URL: $url');
      } else {
        print('StorageService: Upload returned null');
      }
      
      return url;
    } on http.ClientException catch (e) {
      print('StorageService: Network error in downloadAndUpload: $e');
      rethrow;
    } catch (e) {
      print('StorageService: Error in downloadAndUpload: $e');
      print('StorageService: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Generate a unique storage path for character avatar
  String generateCharacterAvatarPath(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'characters/$userId/${timestamp}_${_uuid.v4()}.jpg';
  }

  /// Generate a unique storage path for chat media
  String generateChatMediaPath(String conversationId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'chat_media/$conversationId/${timestamp}_${_uuid.v4()}.jpg';
  }

  /// Generate a unique storage path for user profile
  String generateProfilePath(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'profiles/$userId/${timestamp}.jpg';
  }

  /// Delete a file from Firebase Storage
  Future<bool> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
      return true;
    } catch (e) {
      print('StorageService: Error deleting file: $e');
      return false;
    }
  }

  /// Delete file by URL
  Future<bool> deleteFileByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      print('StorageService: Error deleting file by URL: $e');
      return false;
    }
  }
}

