import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case for updating user profile
class UpdateProfileUseCase {
  final AuthRepository repository;

  UpdateProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    String? displayName,
    XFile? photoFile,
  }) async {
    if (displayName == null && photoFile == null) {
      return Left(ValidationFailure(message: 'Nothing to update'));
    }

    return await repository.updateProfile(
      displayName: displayName,
      photoFile: photoFile,
    );
  }
}

