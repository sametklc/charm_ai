import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import 'auth_providers.dart';

/// Auth state for the controller
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth state class
class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

/// Auth Controller - handles auth actions
class AuthController extends StateNotifier<AuthState> {
  final SignInUseCase _signInUseCase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignInWithAppleUseCase _signInWithAppleUseCase;
  final RegisterUseCase _registerUseCase;
  final SignOutUseCase _signOutUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final UpdateProfileUseCase _updateProfileUseCase;

  AuthController({
    required SignInUseCase signInUseCase,
    required SignInWithGoogleUseCase signInWithGoogleUseCase,
    required SignInWithAppleUseCase signInWithAppleUseCase,
    required RegisterUseCase registerUseCase,
    required SignOutUseCase signOutUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
  })  : _signInUseCase = signInUseCase,
        _signInWithGoogleUseCase = signInWithGoogleUseCase,
        _signInWithAppleUseCase = signInWithAppleUseCase,
        _registerUseCase = registerUseCase,
        _signOutUseCase = signOutUseCase,
        _resetPasswordUseCase = resetPasswordUseCase,
        _updateProfileUseCase = updateProfileUseCase,
        super(const AuthState());

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    print('🔵 AuthController: signInWithEmail START for $email');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final result = await _signInUseCase(email: email, password: password);

      return result.fold(
        (failure) {
          print('❌ AuthController: Sign in FAILED: ${failure.message}');
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: failure.message,
          );
          return false;
        },
        (user) {
          print('✅ AuthController: Sign in SUCCESS for user: ${user.uid}');
          state = state.copyWith(status: AuthStatus.authenticated);
          return true;
        },
      );
    } catch (e, stackTrace) {
      print('❌ AuthController: Unexpected error during signInWithEmail: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _signInWithGoogleUseCase();

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        state = state.copyWith(status: AuthStatus.authenticated);
        return true;
      },
    );
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _signInWithAppleUseCase();

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        state = state.copyWith(status: AuthStatus.authenticated);
        return true;
      },
    );
  }

  /// Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _registerUseCase(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      displayName: displayName,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        state = state.copyWith(status: AuthStatus.authenticated);
        return true;
      },
    );
  }

  /// Sign out
  Future<bool> signOut() async {
    print('🔵 AuthController: signOut START');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _signOutUseCase();

    return result.fold(
      (failure) {
        print('❌ AuthController: signOut FAILED: ${failure.message}');
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        print('✅ AuthController: signOut SUCCESS - State set to unauthenticated');
        // CRITICAL: Set to unauthenticated so AuthWrapper shows LoginScreen
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return true;
      },
    );
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _resetPasswordUseCase(email: email);

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.initial,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(status: AuthStatus.initial);
        return true;
      },
    );
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? displayName,
    XFile? photoFile,
  }) async {
    print('🔵 AuthController: updateProfile START');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _updateProfileUseCase(
      displayName: displayName,
      photoFile: photoFile,
    );

    return result.fold(
      (failure) {
        print('❌ AuthController: Update profile FAILED: ${failure.message}');
        state = state.copyWith(
          status: AuthStatus.initial,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        print('✅ AuthController: Update profile SUCCESS for user: ${user.uid}');
        state = state.copyWith(status: AuthStatus.initial);
        return true;
      },
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Reset state
  void reset() {
    state = const AuthState();
  }
}

/// Provider for AuthController
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    signInUseCase: ref.watch(signInUseCaseProvider),
    signInWithGoogleUseCase: ref.watch(signInWithGoogleUseCaseProvider),
    signInWithAppleUseCase: ref.watch(signInWithAppleUseCaseProvider),
    registerUseCase: ref.watch(registerUseCaseProvider),
    signOutUseCase: ref.watch(signOutUseCaseProvider),
    resetPasswordUseCase: ref.watch(resetPasswordUseCaseProvider),
    updateProfileUseCase: ref.watch(updateProfileUseCaseProvider),
  );
});


