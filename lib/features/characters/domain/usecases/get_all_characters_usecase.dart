import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/character_entity.dart';
import '../repositories/character_repository.dart';

/// Use case to get all available characters
class GetAllCharactersUseCase implements UseCase<List<CharacterEntity>, NoParams> {
  final CharacterRepository repository;

  GetAllCharactersUseCase(this.repository);

  @override
  Future<Either<Failure, List<CharacterEntity>>> call(NoParams params) {
    return repository.getAllCharacters();
  }
}

