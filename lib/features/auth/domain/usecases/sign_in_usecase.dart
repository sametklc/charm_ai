import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case for signing in with email and password
class SignInUseCase {
  final AuthRepository repository;

  SignInUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
  }) async {
    // Validate inputs
    if (email.isEmpty) {
      return const Left(ValidationFailure(message: 'Email cannot be empty'));
    }
    if (password.isEmpty) {
      return const Left(ValidationFailure(message: 'Password cannot be empty'));
    }
    if (password.length < 6) {
      return const Left(ValidationFailure(message: 'Password must be at least 6 characters'));
    }

    return await repository.signInWithEmail(
      email: email.trim(),
      password: password,
    );
  }
}

/// Use case for signing in with Google
class SignInWithGoogleUseCase {
  final AuthRepository repository;

  SignInWithGoogleUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() async {
    return await repository.signInWithGoogle();
  }
}

/// Use case for signing in with Apple
class SignInWithAppleUseCase {
  final AuthRepository repository;

  SignInWithAppleUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() async {
    return await repository.signInWithApple();
  }
}

