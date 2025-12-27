import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/character_entity.dart';
import '../../domain/repositories/character_repository.dart';
import 'predefined_characters.dart';

/// Implementation of Character Repository
/// Currently uses predefined characters, can be extended to use Firestore
class CharacterRepositoryImpl implements CharacterRepository {
  CharacterRepositoryImpl();

  @override
  Future<Either<Failure, List<CharacterEntity>>> getAllCharacters() async {
    try {
      // For now, return predefined characters
      // Later this can be extended to fetch from Firestore
      return Right(PredefinedCharacters.all);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get characters'));
    }
  }

  @override
  Future<Either<Failure, CharacterEntity>> getCharacterById(
    String characterId,
  ) async {
    try {
      final character = PredefinedCharacters.getById(characterId);
      if (character == null) {
        return Left(ServerFailure(message: 'Character not found'));
      }
      return Right(character);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get character'));
    }
  }

  @override
  Future<Either<Failure, List<CharacterEntity>>> getFreeCharacters() async {
    try {
      return Right(PredefinedCharacters.freeCharacters);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get free characters'));
    }
  }

  @override
  Future<Either<Failure, List<CharacterEntity>>> getPremiumCharacters() async {
    try {
      return Right(PredefinedCharacters.premiumCharacters);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get premium characters'));
    }
  }

  @override
  Future<Either<Failure, List<CharacterEntity>>> getCharactersByTrait(
    PersonalityTrait trait,
  ) async {
    try {
      final characters = PredefinedCharacters.all
          .where((c) => c.traits.contains(trait))
          .toList();
      return Right(characters);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get characters by trait'));
    }
  }
}



