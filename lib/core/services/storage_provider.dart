import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

/// Firebase Storage instance provider
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// Storage Service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(storage: ref.watch(firebaseStorageProvider));
});



