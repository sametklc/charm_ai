import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

/// Auth Remote Data Source Interface
abstract class AuthRemoteDataSource {
  /// Get auth state changes stream
  Stream<User?> get authStateChanges;

  /// Get current Firebase user
  User? get currentUser;

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Register with email and password
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in with Google
  Future<UserModel> signInWithGoogle();

  /// Sign in with Apple
  Future<UserModel> signInWithApple();

  /// Sign out
  Future<void> signOut();

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email});

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// Delete user account
  Future<void> deleteAccount();

  /// Save user to Firestore
  Future<void> saveUserToFirestore(UserModel user);

  /// Get user from Firestore
  Future<UserModel?> getUserFromFirestore(String uid);
}

/// Implementation of Auth Remote Data Source
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  CollectionReference get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    print('🔵 AuthRemoteDataSource: signInWithEmail START for $email');
    try {
      print('🔵 AuthRemoteDataSource: Calling Firebase signInWithEmailAndPassword...');
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        print('❌ AuthRemoteDataSource: Firebase returned null user');
        throw AuthException(message: 'Sign in failed');
      }

      print('✅ AuthRemoteDataSource: Firebase Sign-in SUCCESS for uid: ${credential.user!.uid}');

      // Update last login time in Firestore
      print('🔵 AuthRemoteDataSource: Updating last login in Firestore...');
      final user = await _updateLastLogin(credential.user!);
      print('✅ AuthRemoteDataSource: signInWithEmail COMPLETE');
      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ AuthRemoteDataSource: FirebaseAuthException: [${e.code}] ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e, stackTrace) {
      print('❌ AuthRemoteDataSource: Unexpected error during signInWithEmail: $e');
      print('Stack trace: $stackTrace');
      throw AuthException(message: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw AuthException(message: 'Registration failed');
      }

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Create user model
      final userModel = UserModel.fromFirebaseUser(
        uid: credential.user!.uid,
        email: email,
        displayName: displayName,
        photoUrl: credential.user!.photoURL,
      );

      // Save to Firestore
      await saveUserToFirestore(userModel);

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      print('🔵 AuthRemoteDataSource: signInWithGoogle START');
      
      // Trigger the Google Sign In flow
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ AuthRemoteDataSource: Google Sign In cancelled by user');
        throw AuthException(
          message: 'Google sign in was cancelled',
          code: 'cancelled',
        );
      }
      
      print('🔵 AuthRemoteDataSource: Google user obtained: ${googleUser.email}');
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      print('🔵 AuthRemoteDataSource: Signing in to Firebase with Google credential...');
      
      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw AuthException(message: 'Google sign in failed');
      }
      
      print('✅ AuthRemoteDataSource: Firebase sign in SUCCESS for uid: ${userCredential.user!.uid}');
      
      // Update last login time in Firestore
      final user = await _updateLastLogin(userCredential.user!);
      print('✅ AuthRemoteDataSource: signInWithGoogle COMPLETE');
      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ AuthRemoteDataSource: FirebaseAuthException: [${e.code}] ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('❌ AuthRemoteDataSource: Error during Google sign in: $e');
      if (e is AuthException) rethrow;
      throw AuthException(message: 'Google sign in failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithApple() async {
    try {
      print('🔵 AuthRemoteDataSource: signInWithApple START');
      
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      
      // Request credential for Apple Sign In
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      print('🔵 AuthRemoteDataSource: Apple credential obtained');
      
      // Create an OAuthCredential from the credential returned by Apple
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      
      print('🔵 AuthRemoteDataSource: Signing in to Firebase with Apple credential...');
      
      // Sign in to Firebase with the Apple credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
      
      if (userCredential.user == null) {
        throw AuthException(message: 'Apple sign in failed');
      }
      
      print('✅ AuthRemoteDataSource: Firebase sign in SUCCESS for uid: ${userCredential.user!.uid}');
      
      // Apple only provides name on first sign in, so update it if available
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((n) => n != null).join(' ');
        
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }
      
      // Update last login time in Firestore
      final user = await _updateLastLogin(userCredential.user!);
      print('✅ AuthRemoteDataSource: signInWithApple COMPLETE');
      return user;
    } on SignInWithAppleAuthorizationException catch (e) {
      print('❌ AuthRemoteDataSource: Apple Sign In authorization error: ${e.code} - ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AuthException(
          message: 'Apple sign in was cancelled',
          code: 'cancelled',
        );
      }
      throw AuthException(message: 'Apple sign in failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      print('❌ AuthRemoteDataSource: FirebaseAuthException: [${e.code}] ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('❌ AuthRemoteDataSource: Error during Apple sign in: $e');
      if (e is AuthException) rethrow;
      throw AuthException(message: 'Apple sign in failed: ${e.toString()}');
    }
  }

  /// Generate a random nonce for Apple Sign In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<void> signOut() async {
    try {
      print('🔵 AuthRemoteDataSource: signOut START');
      await _firebaseAuth.signOut();
      print('✅ AuthRemoteDataSource: signOut SUCCESS - Firebase auth state cleared');
    } on FirebaseAuthException catch (e) {
      print('❌ AuthRemoteDataSource: signOut FAILED: ${e.message}');
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException(message: 'No user logged in');
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Reload user to get updated profile
      await user.reload();
      final reloadedUser = _firebaseAuth.currentUser!;

      // Update Firestore
      await _usersCollection.doc(reloadedUser.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      // Get updated user from Firestore
      final updatedUser = await getUserFromFirestore(reloadedUser.uid);
      return updatedUser ?? UserModel.fromFirebaseUser(
        uid: reloadedUser.uid,
        email: reloadedUser.email ?? '',
        displayName: displayName ?? reloadedUser.displayName,
        photoUrl: photoUrl ?? reloadedUser.photoURL,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException(message: 'No user logged in');
      }

      // Delete from Firestore first
      await _usersCollection.doc(user.uid).delete();

      // Then delete Firebase Auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<void> saveUserToFirestore(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toJson());
    } catch (e) {
      throw ServerException(message: 'Failed to save user data');
    }
  }

  @override
  Future<UserModel?> getUserFromFirestore(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } on FirebaseException catch (e) {
      // If it's a permission error, return null instead of throwing
      if (e.code == 'permission-denied') {
        print('Auth: Permission denied reading user from Firestore: $uid');
        return null;
      }
      // For other Firestore errors, still throw
      throw ServerException(message: 'Failed to get user data: ${e.message}');
    } catch (e) {
      // For network errors or other issues, return null instead of crashing
      print('Auth: Error getting user from Firestore: $e');
      return null;
    }
  }

  /// Update last login time
  Future<UserModel> _updateLastLogin(User firebaseUser) async {
    print('🔵 AuthRemoteDataSource: _updateLastLogin called for uid: ${firebaseUser.uid}');
    final now = DateTime.now();

    try {
      // Try to update, but use set with merge if document doesn't exist
      print('🔵 AuthRemoteDataSource: Setting user data in Firestore...');
      await _usersCollection.doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'displayName': firebaseUser.displayName,
        'photoUrl': firebaseUser.photoURL,
        'lastLoginAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      print('✅ AuthRemoteDataSource: Firestore user data updated');

      print('🔵 AuthRemoteDataSource: Fetching updated user model from Firestore...');
      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      if (userDoc.exists) {
        print('✅ AuthRemoteDataSource: User model found in Firestore');
        return UserModel.fromFirestore(userDoc);
      } else {
        print('⚠️ AuthRemoteDataSource: User model NOT found in Firestore after update');
      }
    } catch (e, stackTrace) {
      print('❌ AuthRemoteDataSource: Failed to update last login in Firestore: $e');
      print('Stack trace: $stackTrace');
      // Continue with fallback
    }

    // Fallback: return user from Firebase Auth data
    print('🔵 AuthRemoteDataSource: Returning fallback UserModel from Firebase Auth data');
    return UserModel.fromFirebaseUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  /// Handle Firebase Auth exceptions
  AuthException _handleFirebaseAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No account found with this email';
        break;
      case 'wrong-password':
        message = 'Incorrect password';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email';
        break;
      case 'invalid-email':
        message = 'Invalid email address';
        break;
      case 'weak-password':
        message = 'Password is too weak';
        break;
      case 'user-disabled':
        message = 'This account has been disabled';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later';
        break;
      case 'requires-recent-login':
        message = 'Please sign in again to perform this action';
        break;
      default:
        message = e.message ?? 'An authentication error occurred';
    }
    return AuthException(message: message, code: e.code);
  }
}

