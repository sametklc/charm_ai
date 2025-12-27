import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../media_generation/presentation/providers/media_providers.dart';
import '../../../../core/services/storage_provider.dart';
import '../../domain/services/random_character_service.dart';

final randomCharacterServiceProvider = Provider<RandomCharacterService>((ref) {
  return RandomCharacterService(
    firestore: ref.watch(firestoreProvider),
    generateImageUseCase: ref.watch(generateImageUseCaseProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});
