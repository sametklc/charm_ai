import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/character_entity.dart';

/// Character Repository Interface
abstract class CharacterRepository {
  /// Get all available characters
  Future<Either<Failure, List<CharacterEntity>>> getAllCharacters();

  /// Get character by ID
  Future<Either<Failure, CharacterEntity>> getCharacterById(String characterId);

  /// Get free characters only
  Future<Either<Failure, List<CharacterEntity>>> getFreeCharacters();

  /// Get premium characters only
  Future<Either<Failure, List<CharacterEntity>>> getPremiumCharacters();

  /// Get characters by trait
  Future<Either<Failure, List<CharacterEntity>>> getCharactersByTrait(
    PersonalityTrait trait,
  );
}



