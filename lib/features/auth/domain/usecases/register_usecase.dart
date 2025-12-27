import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case for registering a new user with email and password
class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
    required String confirmPassword,
    String? displayName,
  }) async {
    // Validate email
    if (email.isEmpty) {
      return const Left(ValidationFailure(message: 'Email cannot be empty'));
    }
    if (!_isValidEmail(email)) {
      return const Left(ValidationFailure(message: 'Please enter a valid email address'));
    }

    // Validate password
    if (password.isEmpty) {
      return const Left(ValidationFailure(message: 'Password cannot be empty'));
    }
    if (password.length < 6) {
      return const Left(ValidationFailure(message: 'Password must be at least 6 characters'));
    }
    if (password != confirmPassword) {
      return const Left(ValidationFailure(message: 'Passwords do not match'));
    }

    // Validate display name if provided
    if (displayName != null && displayName.isNotEmpty && displayName.length < 2) {
      return const Left(ValidationFailure(message: 'Name must be at least 2 characters'));
    }

    return await repository.registerWithEmail(
      email: email.trim(),
      password: password,
      displayName: displayName?.trim(),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}



