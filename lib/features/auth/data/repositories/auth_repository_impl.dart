import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

/// Implementation of Auth Repository
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final StorageService storageService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  @override
  Stream<UserEntity?> get authStateChanges {
    print('🔵 AuthRepository: authStateChanges stream started');
    return remoteDataSource.authStateChanges.asyncMap((firebaseUser) async {
      print('🔵 AuthRepository: authStateChanges received firebaseUser: ${firebaseUser?.uid ?? "NULL"}');
      if (firebaseUser == null) return null;

      // Try to get user from Firestore
      try {
        print('🔵 AuthRepository: Fetching user from Firestore for uid: ${firebaseUser.uid}');
        final userModel = await remoteDataSource.getUserFromFirestore(firebaseUser.uid);
        if (userModel != null) {
          print('✅ AuthRepository: User found in Firestore');
          return userModel.toEntity();
        } else {
          print('⚠️ AuthRepository: User NOT found in Firestore');
        }
      } catch (e) {
        // If Firestore read fails (permissions, network, etc.), fallback to Firebase Auth data
        print('❌ AuthRepository: Failed to get user from Firestore, using Firebase Auth data: $e');
      }

      // Fallback to Firebase Auth data
      print('🔵 AuthRepository: Returning fallback UserEntity from Firebase Auth data');
      return UserModel.fromFirebaseUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
      ).toEntity();
    }).handleError((error) {
      // Handle stream errors gracefully
      print('❌ AuthRepository: Auth stream error: $error');
      return null;
    });
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final firebaseUser = remoteDataSource.currentUser;
      if (firebaseUser == null) return const Right(null);

      // Try to get user from Firestore, but don't fail if it doesn't exist or has permission issues
      try {
        final userModel = await remoteDataSource.getUserFromFirestore(firebaseUser.uid);
        if (userModel != null) {
          return Right(userModel.toEntity());
        }
      } catch (e) {
        // If Firestore read fails, fallback to Firebase Auth data
        print('Auth: Failed to get user from Firestore, using Firebase Auth data: $e');
      }

      // Fallback to Firebase Auth data
      return Right(UserModel.fromFirebaseUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
      ).toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get current user: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code != null ? int.tryParse(e.code!) : null));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Sign in failed'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final user = await remoteDataSource.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return Right(user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code != null ? int.tryParse(e.code!) : null));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Registration failed'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final user = await remoteDataSource.signInWithGoogle();
      return Right(user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code != null ? int.tryParse(e.code!) : null));
    } catch (e) {
      return Left(ServerFailure(message: 'Google sign in failed'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithApple() async {
    try {
      final user = await remoteDataSource.signInWithApple();
      return Right(user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code != null ? int.tryParse(e.code!) : null));
    } catch (e) {
      return Left(ServerFailure(message: 'Apple sign in failed'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Sign out failed'));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail({required String email}) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email: email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to send password reset email'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? displayName,
    String? photoUrl,
    XFile? photoFile,
  }) async {
    try {
      String? finalPhotoUrl = photoUrl;

      // If photoFile is provided, upload it to Firebase Storage
      if (photoFile != null) {
        final user = remoteDataSource.currentUser;
        if (user == null) {
          return Left(AuthFailure(message: 'No user logged in'));
        }

        final storagePath = storageService.generateProfilePath(user.uid);
        final file = File(photoFile.path);

        finalPhotoUrl = await storageService.uploadFile(
          file: file,
          path: storagePath,
        );

        if (finalPhotoUrl == null) {
          return Left(ServerFailure(message: 'Failed to upload profile photo'));
        }
      }

      final user = await remoteDataSource.updateProfile(
        displayName: displayName,
        photoUrl: finalPhotoUrl,
      );
      return Right(user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update profile'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await remoteDataSource.deleteAccount();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete account'));
    }
  }
}

