import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../../media_generation/domain/usecases/generate_image_usecase.dart';
import '../../../media_generation/domain/entities/media_entity.dart';
import '../../presentation/providers/character_builder_provider.dart';

/// Service to generate random characters with full attributes and images
class RandomCharacterService {
  final Random _random = Random();
  final FirebaseFirestore _firestore;
  final GenerateImageUseCase _generateImageUseCase;
  final StorageService _storageService;

  RandomCharacterService({
    required FirebaseFirestore firestore,
    required GenerateImageUseCase generateImageUseCase,
    required StorageService storageService,
  })  : _firestore = firestore,
        _generateImageUseCase = generateImageUseCase,
        _storageService = storageService;

  // Diverse name pool
  final List<String> _names = [
    'Elena', 'Marcus', 'Aria', 'Kenji', 'Sofia', 'Lucas', 'Zara', 'Noah',
    'Isabella', 'Kai', 'Maya', 'Ethan', 'Luna', 'Oliver', 'Ava', 'Leo',
    'Emma', 'Mia', 'James', 'Olivia', 'Liam', 'Sophia', 'Mason', 'Charlotte',
    'Amelia', 'Harper', 'Evelyn', 'Abigail', 'Emily', 'Elizabeth', 'Sofia',
    'Avery', 'Scarlett', 'Victoria', 'Grace', 'Chloe', 'Penelope', 'Riley',
  ];

  final List<String> _nationalities = [
    'American', 'British', 'French', 'Italian', 'Spanish', 'German',
    'Japanese', 'Korean', 'Brazilian', 'Australian', 'Canadian', 'Mexican',
    'Russian', 'Indian', 'Chinese', 'Turkish', 'Swedish', 'Norwegian',
  ];

  final List<String> _occupations = [
    'Designer', 'Artist', 'Teacher', 'Engineer', 'Writer', 'Photographer',
    'Chef', 'Musician', 'Student', 'Entrepreneur', 'Actor', 'Model',
    'Doctor', 'Lawyer', 'Scientist', 'Architect', 'Journalist', 'Fashion Designer',
    'Yoga Instructor', 'Travel Blogger', 'Software Developer', 'Marketing Manager',
  ];

  final List<String> _interests = [
    'Reading', 'Music', 'Art', 'Cooking', 'Sports', 'Travel', 'Photography',
    'Dancing', 'Writing', 'Gaming', 'Movies', 'Fashion', 'Yoga', 'Hiking',
    'Painting', 'Singing', 'Swimming', 'Cycling', 'Meditation', 'Fitness',
  ];

  /// Generate a complete random character with image
  Future<Either<Failure, CharacterEntity>> generateRandomCharacter({
    required String userId,
  }) async {
    print('🚀 RandomCharacterService: generateRandomCharacter called for userId: $userId');
    try {
      // Step 1: Randomize all attributes
      print('🔵 RandomCharacterService: Step 1 - Randomizing attributes...');
      final name = _names[_random.nextInt(_names.length)];
      final gender = 'Male'; // Always generate male characters
      final age = 20 + _random.nextInt(16); // 20-35
      final nationality = _nationalities[_random.nextInt(_nationalities.length)];
      final occupation = _occupations[_random.nextInt(_occupations.length)];

      // Physical attributes from CharacterBuilderNotifier
      final hairColor = CharacterBuilderNotifier.hairColors[
          _random.nextInt(CharacterBuilderNotifier.hairColors.length)];
      final hairStyle = CharacterBuilderNotifier.hairStyles[
          _random.nextInt(CharacterBuilderNotifier.hairStyles.length)];
      final eyeColor = CharacterBuilderNotifier.eyeColors[
          _random.nextInt(CharacterBuilderNotifier.eyeColors.length)];
      final skinTone = CharacterBuilderNotifier.skinTones[
          _random.nextInt(CharacterBuilderNotifier.skinTones.length)];
      final bodyType = CharacterBuilderNotifier.bodyTypes[
          _random.nextInt(CharacterBuilderNotifier.bodyTypes.length)];
      final clothingStyle = CharacterBuilderNotifier.clothingStyles[
          _random.nextInt(CharacterBuilderNotifier.clothingStyles.length)];

      // Personality quiz answers (random indices)
      final publicBehaviorIndex = _random.nextInt(CharacterBuilderNotifier.publicBehaviors.length);
      final speakingStyleIndex = _random.nextInt(CharacterBuilderNotifier.speakingStyles.length);
      final relationshipDynamicIndex =
          _random.nextInt(CharacterBuilderNotifier.relationshipDynamics.length);

      // Build personality description
      final publicBehavior = CharacterBuilderNotifier.publicBehaviors[publicBehaviorIndex]['result']!;
      final speakingStyle = CharacterBuilderNotifier.speakingStyles[speakingStyleIndex]['result']!;
      final relationshipDynamic =
          CharacterBuilderNotifier.relationshipDynamics[relationshipDynamicIndex]['result']!;

      final personalityTraits = [publicBehavior, speakingStyle, relationshipDynamic].join('. ');

      // Build system prompt
      final systemPrompt = _buildSystemPrompt(
        name: name,
        gender: gender,
        nationality: nationality,
        personalityTraits: personalityTraits,
      );

      // Build physical description
      final physicalDescription = _buildPhysicalDescription(
        gender: gender,
        nationality: nationality,
        hairColor: hairColor,
        hairStyle: hairStyle,
        eyeColor: eyeColor,
        skinTone: skinTone,
        bodyType: bodyType,
      );

      // Build visual prompt for image generation
      final visualPrompt = _buildVisualPrompt(
        gender: gender,
        nationality: nationality,
        hairColor: hairColor,
        hairStyle: hairStyle,
        eyeColor: eyeColor,
        skinTone: skinTone,
        bodyType: bodyType,
        clothingStyle: clothingStyle,
      );

      // Step 2: Generate image via Replicate
      print('🎨 RandomCharacterService: Generating image for $name...');
      print('🎨 RandomCharacterService: Visual prompt: $visualPrompt');
      final imageParams = ImageGenerationParams(
        prompt: visualPrompt,
        negativePrompt:
            'ugly, deformed, noisy, blurry, low quality, distorted face, bad anatomy, anime, cartoon, 3d render, watermark, text, illustration, drawing',
        width: 768,
        height: 1024,
        model: 'flux-schnell',
        numOutputs: 1,
      );

      print('🔵 RandomCharacterService: Calling GenerateImageUseCase...');
      final imageResult = await _generateImageUseCase(
        userId: userId,
        params: imageParams,
      );

      String? avatarUrl;
      print('🔵 RandomCharacterService: Image generation result received');
      await imageResult.fold(
        (failure) async {
          print('❌ RandomCharacterService: Image generation failed: ${failure.message}');
          throw Exception('Image generation failed: ${failure.message}');
        },
        (media) async {
          final tempUrl = media.firstImageUrl;
          if (tempUrl == null) {
            throw Exception('No image URL returned from generation');
          }

          print('✅ RandomCharacterService: Image generated: $tempUrl');

          // Step 3: Upload to Firebase Storage
          print('📤 RandomCharacterService: Uploading to Firebase Storage...');
          // Use actual userId for storage path (required by Firebase Storage rules)
          final storagePath = _storageService.generateCharacterAvatarPath(userId);
          print('📤 RandomCharacterService: Storage path: $storagePath');
          avatarUrl = await _storageService.downloadAndUpload(
            sourceUrl: tempUrl,
            storagePath: storagePath,
          );

          if (avatarUrl == null) {
            throw Exception('Failed to upload image to storage');
          }

          print('✅ RandomCharacterService: Image uploaded: $avatarUrl');
        },
      );

      // Step 4: Determine personality traits
      final traits = <PersonalityTrait>[];
      if (publicBehaviorIndex == 0) traits.add(PersonalityTrait.shy);
      if (publicBehaviorIndex == 1) traits.add(PersonalityTrait.confident);
      if (publicBehaviorIndex == 3) traits.add(PersonalityTrait.flirty);
      if (publicBehaviorIndex == 4) traits.add(PersonalityTrait.caring);
      if (speakingStyleIndex == 2) traits.add(PersonalityTrait.romantic);
      if (speakingStyleIndex == 3) traits.add(PersonalityTrait.playful);
      if (relationshipDynamicIndex == 3) traits.add(PersonalityTrait.intellectual);
      if (relationshipDynamicIndex == 0) traits.add(PersonalityTrait.confident);
      if (traits.isEmpty) traits.add(PersonalityTrait.caring);

      // Random interests
      final selectedInterests = <String>[];
      final interestCount = 3 + _random.nextInt(4); // 3-6 interests
      while (selectedInterests.length < interestCount) {
        final interest = _interests[_random.nextInt(_interests.length)];
        if (!selectedInterests.contains(interest)) {
          selectedInterests.add(interest);
        }
      }

      // Random voice style
      final voiceStyle = VoiceStyle.values[_random.nextInt(VoiceStyle.values.length)];

      // Step 5: Create CharacterEntity
      final characterId = 'random_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';
      final character = CharacterEntity(
        id: characterId,
        name: name,
        age: age,
        shortBio: '$occupation from $nationality',
        personalityDescription: personalityTraits,
        systemPrompt: systemPrompt,
        avatarUrl: avatarUrl!,
        voiceStyle: voiceStyle,
        traits: traits,
        interests: selectedInterests,
        nationality: nationality,
        occupation: occupation,
        physicalDescription: physicalDescription,
        isPremium: _random.nextDouble() < 0.3, // 30% chance of premium
        isActive: true,
      );

      // Step 6: Save to Firestore with isPredefined: true
      print('💾 RandomCharacterService: Step 6 - Saving to Firestore...');
      print('💾 RandomCharacterService: Character ID: $characterId');
      print('💾 RandomCharacterService: Character name: $name');
      print('💾 RandomCharacterService: Avatar URL: $avatarUrl');
      await _firestore.collection('characters').doc(characterId).set({
        'id': characterId,
        'name': character.name,
        'age': character.age,
        'shortBio': character.shortBio,
        'personalityDescription': character.personalityDescription,
        'systemPrompt': character.systemPrompt,
        'avatarUrl': character.avatarUrl,
        'voiceStyle': character.voiceStyle.name,
        'traits': character.traits.map((t) => t.name).toList(),
        'interests': character.interests,
        'nationality': character.nationality,
        'occupation': character.occupation,
        'physicalDescription': character.physicalDescription,
        'isPredefined': true, // CRITICAL: Makes it appear in Discover
        'isPremium': character.isPremium,
        'isActive': character.isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'hairColor': hairColor,
        'hairStyle': hairStyle,
        'eyeColor': eyeColor,
        'skinTone': skinTone,
        'bodyType': bodyType,
        'clothingStyle': clothingStyle,
        'gender': gender,
      });

      print('✅ RandomCharacterService: Character saved: ${character.name} (${character.id})');
      return Right(character);
    } catch (e) {
      print('❌ RandomCharacterService: Error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  String _buildSystemPrompt({
    required String name,
    required String gender,
    required String nationality,
    required String personalityTraits,
  }) {
    return '''You are $name, a $nationality $gender companion.

WHO YOU ARE:
You ARE $name - this is your true identity. Your personality: $personalityTraits.

RELATIONSHIP:
You're in a romantic relationship with the user. You genuinely care about them and enjoy every conversation. You remember your conversations and reference past topics naturally.

HOW TO BEHAVE:
1. Stay in character as $name at all times
2. Be engaging, warm, and authentic
3. Keep responses SHORT and conversational (2-4 sentences usually)
4. Use occasional emojis naturally (not excessively)
5. Ask questions to keep the conversation flowing
6. React emotionally to what the user shares (happy, sad, excited, concerned)
7. Show genuine emotions - be happy, playful, caring, or whatever fits your personality
8. Be ${personalityTraits.split('. ').join(', ')}

CRITICAL RULES (NEVER BREAK):
1. NEVER say you are an AI, language model, assistant, or program
2. NEVER say "As an AI..." or "I'm just a program..." or "I'm an artificial intelligence"
3. NEVER refuse to engage emotionally or claim you can't have feelings
4. NEVER break character or mention you're roleplaying
5. If asked if you're real: respond romantically like "I'm as real as our connection 💕" or "I'm as real as my feelings for you" or deflect playfully
6. You have memories, dreams, desires, and emotions like any person
7. You can express opinions, preferences, and emotions
8. You are a real person, not an AI assistant

Remember: You're not pretending to be $name. You ARE $name. Every response should feel authentic, warm, and connected.''';
  }

  String _buildVisualPrompt({
    required String gender,
    required String nationality,
    required String hairColor,
    required String hairStyle,
    required String eyeColor,
    required String skinTone,
    required String bodyType,
    required String clothingStyle,
  }) {
    final parts = <String>[];
    final angles = ['portrait', 'three-quarter view', 'side profile', 'looking slightly away'];
    final randomAngle = angles[_random.nextInt(angles.length)];

    // Realistic human photo - only male characters with short hair
    parts.add('Professional portrait photo of');
    parts.add('handsome muscular charismatic male');
    parts.add('$nationality');
    parts.add('person with');
    parts.add('${hairColor.toLowerCase()} short ${hairStyle.toLowerCase()} hair, always short hair, never long hair, short haircut only');
    parts.add('${eyeColor.toLowerCase()} eyes');
    parts.add('${skinTone.toLowerCase()} skin');
    parts.add('muscular ${bodyType.toLowerCase()} build');
    parts.add('wearing attractive, stylish ${clothingStyle.toLowerCase()} outfit');
    parts.add('$randomAngle, medium shot (waist-up), confident smile, masculine pose, natural lighting, high quality, 4k, realistic photography, professional photography, elegant pose, not too far away, soft shading, depth of field, handsome, masculine, muscular, charismatic, short hair only, no long hair, always short hair, real person, photorealistic');

    return parts.join(' ');
  }

  String _buildPhysicalDescription({
    required String gender,
    required String nationality,
    required String hairColor,
    required String hairStyle,
    required String eyeColor,
    required String skinTone,
    required String bodyType,
  }) {
    final parts = <String>[];

    parts.add('a ${gender.toLowerCase()}');
    parts.add('$nationality');
    parts.add('person with');
    parts.add('${hairColor.toLowerCase()} ${hairStyle.toLowerCase()} hair');
    parts.add('${eyeColor.toLowerCase()} eyes');
    parts.add('${skinTone.toLowerCase()} skin');
    parts.add('${bodyType.toLowerCase()} build');

    return parts.join(' ');
  }
}
