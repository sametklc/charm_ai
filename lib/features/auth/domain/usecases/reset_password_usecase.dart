import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for sending password reset email
class ResetPasswordUseCase {
  final AuthRepository repository;

  ResetPasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({required String email}) async {
    // Validate email
    if (email.isEmpty) {
      return const Left(ValidationFailure(message: 'Email cannot be empty'));
    }
    if (!_isValidEmail(email)) {
      return const Left(ValidationFailure(message: 'Please enter a valid email address'));
    }

    return await repository.sendPasswordResetEmail(email: email.trim());
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}



