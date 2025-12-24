import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw AuthException(message: 'Sign in failed');
      }

      // Update last login time in Firestore
      final user = await _updateLastLogin(credential.user!);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
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
    // TODO: Implement Google Sign In in Phase 2.5
    // Requires google_sign_in package
    throw AuthException(
      message: 'Google Sign In not yet implemented',
      code: 'not-implemented',
    );
  }

  @override
  Future<UserModel> signInWithApple() async {
    // TODO: Implement Apple Sign In in Phase 2.5
    // Requires sign_in_with_apple package
    throw AuthException(
      message: 'Apple Sign In not yet implemented',
      code: 'not-implemented',
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
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

      // Update Firestore
      await _usersCollection.doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      // Get updated user from Firestore
      final updatedUser = await getUserFromFirestore(user.uid);
      return updatedUser ?? UserModel.fromFirebaseUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName,
        photoUrl: photoUrl ?? user.photoURL,
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
    } catch (e) {
      throw ServerException(message: 'Failed to get user data');
    }
  }

  /// Update last login time
  Future<UserModel> _updateLastLogin(User firebaseUser) async {
    final now = DateTime.now();

    await _usersCollection.doc(firebaseUser.uid).update({
      'lastLoginAt': Timestamp.fromDate(now),
    });

    final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
    if (userDoc.exists) {
      return UserModel.fromFirestore(userDoc);
    }

    // If user doesn't exist in Firestore (edge case), create them
    final newUser = UserModel.fromFirebaseUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
    await saveUserToFirestore(newUser);
    return newUser;
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

