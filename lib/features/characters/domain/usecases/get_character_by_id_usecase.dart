import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/character_entity.dart';
import '../repositories/character_repository.dart';

/// Use case to get a character by ID
class GetCharacterByIdUseCase implements UseCase<CharacterEntity, CharacterParams> {
  final CharacterRepository repository;

  GetCharacterByIdUseCase(this.repository);

  @override
  Future<Either<Failure, CharacterEntity>> call(CharacterParams params) {
    return repository.getCharacterById(params.characterId);
  }
}

class CharacterParams extends Equatable {
  final String characterId;

  const CharacterParams({required this.characterId});

  @override
  List<Object?> get props => [characterId];
}

