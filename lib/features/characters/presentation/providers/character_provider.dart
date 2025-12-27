import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/character_repository_impl.dart';
import '../../data/repositories/predefined_characters.dart';
import '../../domain/entities/character_entity.dart';
import '../../domain/repositories/character_repository.dart';
import '../../domain/usecases/get_all_characters_usecase.dart';
import '../../domain/usecases/get_character_by_id_usecase.dart';
import '../../../../core/usecases/usecase.dart';

/// Character Repository Provider
final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  return CharacterRepositoryImpl();
});

/// Get All Characters Use Case Provider
final getAllCharactersUseCaseProvider = Provider<GetAllCharactersUseCase>((ref) {
  return GetAllCharactersUseCase(ref.watch(characterRepositoryProvider));
});

/// Get Character By Id Use Case Provider
final getCharacterByIdUseCaseProvider = Provider<GetCharacterByIdUseCase>((ref) {
  return GetCharacterByIdUseCase(ref.watch(characterRepositoryProvider));
});

/// All Characters Provider
final allCharactersProvider = FutureProvider<List<CharacterEntity>>((ref) async {
  final useCase = ref.watch(getAllCharactersUseCaseProvider);
  final result = await useCase(NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (characters) => characters,
  );
});

/// Single Character Provider (by ID)
final characterByIdProvider = FutureProvider.family<CharacterEntity?, String>((ref, characterId) async {
  final useCase = ref.watch(getCharacterByIdUseCaseProvider);
  final result = await useCase(CharacterParams(characterId: characterId));
  return result.fold(
    (failure) => null,
    (character) => character,
  );
});

/// Selected Character Provider
final selectedCharacterProvider = StateProvider<CharacterEntity?>((ref) => null);

/// Free Characters Provider
final freeCharactersProvider = Provider<List<CharacterEntity>>((ref) {
  return PredefinedCharacters.freeCharacters;
});

/// Premium Characters Provider
final premiumCharactersProvider = Provider<List<CharacterEntity>>((ref) {
  return PredefinedCharacters.premiumCharacters;
});

/// Character State for UI
enum CharacterListState { loading, loaded, error }

/// Character List Notifier
class CharacterListNotifier extends StateNotifier<CharacterListState> {
  final Ref ref;

  CharacterListNotifier(this.ref) : super(CharacterListState.loading) {
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    state = CharacterListState.loading;
    try {
      await ref.read(allCharactersProvider.future);
      state = CharacterListState.loaded;
    } catch (e) {
      state = CharacterListState.error;
    }
  }

  void selectCharacter(CharacterEntity character) {
    ref.read(selectedCharacterProvider.notifier).state = character;
  }

  void clearSelection() {
    ref.read(selectedCharacterProvider.notifier).state = null;
  }

  Future<void> refresh() async {
    ref.invalidate(allCharactersProvider);
    await _loadCharacters();
  }
}

/// Character List State Provider
final characterListStateProvider =
    StateNotifierProvider<CharacterListNotifier, CharacterListState>((ref) {
  return CharacterListNotifier(ref);
});



