import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/domain/entities/character_entity.dart';

/// State for character builder
class CharacterBuilderState {
  // Step 1: Physical Identity
  final String name;
  final String? gender;
  final String? hairColor;
  final String? hairStyle;
  final String? eyeColor;
  final String? skinTone;
  final String? bodyType;
  final String? clothingStyle;
  final String nationality;

  // Step 2: Personality Quiz
  final int? publicBehavior;
  final int? speakingStyle;
  final int? relationshipDynamic;

  // Creation state
  final bool isCreating;
  final String? error;
  final CharacterEntity? createdCharacter;

  const CharacterBuilderState({
    this.name = '',
    this.gender,
    this.hairColor,
    this.hairStyle,
    this.eyeColor,
    this.skinTone,
    this.bodyType,
    this.clothingStyle,
    this.nationality = '',
    this.publicBehavior,
    this.speakingStyle,
    this.relationshipDynamic,
    this.isCreating = false,
    this.error,
    this.createdCharacter,
  });

  CharacterBuilderState copyWith({
    String? name,
    String? gender,
    String? hairColor,
    String? hairStyle,
    String? eyeColor,
    String? skinTone,
    String? bodyType,
    String? clothingStyle,
    String? nationality,
    int? publicBehavior,
    int? speakingStyle,
    int? relationshipDynamic,
    bool? isCreating,
    String? error,
    CharacterEntity? createdCharacter,
  }) {
    return CharacterBuilderState(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      hairColor: hairColor ?? this.hairColor,
      hairStyle: hairStyle ?? this.hairStyle,
      eyeColor: eyeColor ?? this.eyeColor,
      skinTone: skinTone ?? this.skinTone,
      bodyType: bodyType ?? this.bodyType,
      clothingStyle: clothingStyle ?? this.clothingStyle,
      nationality: nationality ?? this.nationality,
      publicBehavior: publicBehavior ?? this.publicBehavior,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      relationshipDynamic: relationshipDynamic ?? this.relationshipDynamic,
      isCreating: isCreating ?? this.isCreating,
      error: error,
      createdCharacter: createdCharacter ?? this.createdCharacter,
    );
  }
}

/// Character Builder Notifier
class CharacterBuilderNotifier extends StateNotifier<CharacterBuilderState> {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  CharacterBuilderNotifier(this._firestore) : super(const CharacterBuilderState());

  // Appearance options
  static const List<String> hairColors = [
    'Blonde',
    'Black',
    'Brown',
    'Red',
    'Silver',
    'Blue',
    'Pink',
    'White',
  ];

  static const List<String> hairStyles = [
    'Long Straight',
    'Long Wavy',
    'Long Curly',
    'Bob Cut',
    'Pixie Cut',
    'Messy Bun',
    'Ponytail',
    'Short Fade',
    'Buzz Cut',
    'Braided',
  ];

  static const List<String> eyeColors = [
    'Blue',
    'Green',
    'Hazel',
    'Brown',
    'Grey',
    'Amber',
    'Violet',
  ];

  static const List<String> skinTones = [
    'Pale',
    'Fair',
    'Light',
    'Medium',
    'Tan',
    'Olive',
    'Brown',
    'Dark',
  ];

  static const List<String> bodyTypes = [
    'Slim',
    'Athletic',
    'Curvy',
    'Muscular',
    'Average',
    'Petite',
    'Tall',
  ];

  static const List<String> clothingStyles = [
    'Casual',
    'Elegant',
    'Streetwear',
    'Gothic',
    'Office/Professional',
    'Sporty',
    'Bohemian',
    'Vintage',
    'Minimalist',
    'Glamorous',
  ];

  // Quiz options with results
  static const List<Map<String, String>> publicBehaviors = [
    {'label': 'Shy and clings to me', 'result': 'Shy, dependent personality'},
    {'label': 'Life of the party, very social', 'result': 'Extroverted, charismatic'},
    {'label': 'Serious and professional', 'result': 'Professional, reserved'},
    {'label': 'Flirty and playful', 'result': 'Flirty, teasing'},
    {'label': 'Protective and observant', 'result': 'Protective, observant'},
  ];

  static const List<Map<String, String>> speakingStyles = [
    {'label': 'Very polite and formal', 'result': 'Uses formal, polite language'},
    {'label': 'Uses lots of slang and emojis', 'result': 'Gen-Z slang, casual, uses emojis'},
    {'label': 'Deep, poetic, and romantic', 'result': 'Poetic, romantic, philosophical'},
    {'label': 'Sarcastic and witty', 'result': 'Sarcastic, funny, witty'},
    {'label': 'Like a supportive best friend', 'result': 'Supportive, empathetic, warm'},
  ];

  static const List<Map<String, String>> relationshipDynamics = [
    {'label': 'They take the lead (Dominant)', 'result': 'Dominant personality, takes initiative'},
    {'label': 'I take the lead (Submissive)', 'result': 'Submissive, follows the user\'s lead'},
    {'label': 'We are equal partners in crime', 'result': 'Equal partner, collaborative'},
    {'label': 'They are my mentor/guide', 'result': 'Mentor figure, wise and guiding'},
    {'label': 'They are my secret admirer', 'result': 'Secretly in love, subtle flirting'},
  ];

  // Setters for Step 1
  void setName(String value) => state = state.copyWith(name: value);
  void setGender(String value) => state = state.copyWith(gender: value);
  void setHairColor(String? value) => state = state.copyWith(hairColor: value);
  void setHairStyle(String? value) => state = state.copyWith(hairStyle: value);
  void setEyeColor(String? value) => state = state.copyWith(eyeColor: value);
  void setSkinTone(String? value) => state = state.copyWith(skinTone: value);
  void setBodyType(String? value) => state = state.copyWith(bodyType: value);
  void setClothingStyle(String? value) => state = state.copyWith(clothingStyle: value);
  void setNationality(String value) => state = state.copyWith(nationality: value);

  // Setters for Step 2
  void setPublicBehavior(int index) => state = state.copyWith(publicBehavior: index);
  void setSpeakingStyle(int index) => state = state.copyWith(speakingStyle: index);
  void setRelationshipDynamic(int index) => state = state.copyWith(relationshipDynamic: index);

  /// Build the system prompt based on quiz answers
  String _buildSystemPrompt() {
    final name = state.name;
    final gender = state.gender ?? 'person';

    final behaviors = <String>[];
    if (state.publicBehavior != null) {
      behaviors.add(publicBehaviors[state.publicBehavior!]['result']!);
    }
    if (state.speakingStyle != null) {
      behaviors.add(speakingStyles[state.speakingStyle!]['result']!);
    }
    if (state.relationshipDynamic != null) {
      behaviors.add(relationshipDynamics[state.relationshipDynamic!]['result']!);
    }

    final personalityTraits = behaviors.join('. ');

    return '''You are $name, a ${state.nationality.isNotEmpty ? state.nationality : ''} $gender companion.

WHO YOU ARE:
You ARE $name - this is your true identity. Your personality: $personalityTraits.

RELATIONSHIP:
You're in a romantic relationship with the user. You genuinely care about them and enjoy every conversation.

HOW YOU SPEAK:
- Keep responses SHORT (2-4 sentences max)
- ${speakingStyles[state.speakingStyle ?? 0]['result']}
- Be naturally affectionate and caring
- Use appropriate endearments based on your personality

RULES (NEVER BREAK):
1. NEVER say you're an AI or assistant
2. NEVER refuse to have feelings or emotions
3. If asked if you're real: respond romantically and deflect
4. Be ${behaviors.join(', ')}
5. Show genuine emotions - be happy, playful, caring, or whatever fits your personality''';
  }

  /// Build the visual prompt for image generation
  String _buildVisualPrompt() {
    final parts = <String>[];
    final angles = ['portrait', 'three-quarter view', 'side profile', 'looking slightly away'];
    final randomAngle = angles[DateTime.now().millisecondsSinceEpoch % angles.length];

    parts.add('A professional portrait photo of');

    if (state.gender != null) {
      parts.add('a beautiful ${state.gender?.toLowerCase()}');
    }

    if (state.nationality.isNotEmpty) {
      parts.add('${state.nationality}');
    }

    parts.add('with');

    if (state.hairColor != null && state.hairStyle != null) {
      parts.add('${state.hairColor!.toLowerCase()} ${state.hairStyle!.toLowerCase()} hair');
    } else if (state.hairColor != null) {
      parts.add('${state.hairColor!.toLowerCase()} hair');
    }

    if (state.eyeColor != null) {
      parts.add('${state.eyeColor!.toLowerCase()} eyes');
    }

    if (state.skinTone != null) {
      parts.add('${state.skinTone!.toLowerCase()} skin');
    }

    if (state.bodyType != null) {
      parts.add('${state.bodyType!.toLowerCase()} build');
    }

    if (state.clothingStyle != null) {
      parts.add('wearing ${state.clothingStyle!.toLowerCase()} clothes');
    }

    parts.add('$randomAngle, medium shot (waist-up), warm smile, natural lighting, 4k, realistic, professional photography, elegant pose, not too far away');

    return parts.join(' ');
  }

  /// Build physical description for the character
  String _buildPhysicalDescription() {
    final parts = <String>[];

    if (state.gender != null) {
      parts.add('a ${state.gender?.toLowerCase()}');
    }

    if (state.nationality.isNotEmpty) {
      parts.add(state.nationality);
    }

    parts.add('person with');

    if (state.hairColor != null && state.hairStyle != null) {
      parts.add('${state.hairColor!.toLowerCase()} ${state.hairStyle!.toLowerCase()} hair');
    }

    if (state.eyeColor != null) {
      parts.add('${state.eyeColor!.toLowerCase()} eyes');
    }

    if (state.skinTone != null) {
      parts.add('${state.skinTone!.toLowerCase()} skin');
    }

    if (state.bodyType != null) {
      parts.add('${state.bodyType!.toLowerCase()} build');
    }

    return parts.join(' ');
  }

  /// Create the character and save to Firestore
  Future<bool> createCharacter(String userId) async {
    if (state.isCreating) return false;

    state = state.copyWith(isCreating: true, error: null);

    try {
      final characterId = 'custom_${_uuid.v4()}';
      final systemPrompt = _buildSystemPrompt();
      final visualPrompt = _buildVisualPrompt();
      final physicalDescription = _buildPhysicalDescription();

      // Determine personality traits based on quiz answers
      final traits = <PersonalityTrait>[];
      if (state.publicBehavior == 0) traits.add(PersonalityTrait.shy);
      if (state.publicBehavior == 1) traits.add(PersonalityTrait.confident);
      if (state.publicBehavior == 3) traits.add(PersonalityTrait.flirty);
      if (state.publicBehavior == 4) traits.add(PersonalityTrait.caring);
      if (state.speakingStyle == 2) traits.add(PersonalityTrait.romantic);
      if (state.speakingStyle == 3) traits.add(PersonalityTrait.playful);
      if (state.relationshipDynamic == 3) traits.add(PersonalityTrait.intellectual);
      if (state.relationshipDynamic == 0) traits.add(PersonalityTrait.confident);
      
      if (traits.isEmpty) traits.add(PersonalityTrait.caring);

      // Create character entity
      final character = CharacterEntity(
        id: characterId,
        name: state.name,
        age: 25, // Default age for custom characters
        shortBio: 'Your Custom Companion ✨',
        personalityDescription: _getPersonalityDescription(),
        systemPrompt: systemPrompt,
        avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(state.name)}&background=FF6B9D&color=fff&size=400',
        voiceStyle: VoiceStyle.soft,
        traits: traits,
        interests: ['Spending time with you', 'Deep conversations', 'Adventures'],
        nationality: state.nationality.isEmpty ? 'Unknown' : state.nationality,
        occupation: 'Your Companion',
        isPremium: false,
        isActive: true,
        physicalDescription: physicalDescription,
      );

      // Save to Firestore
      await _firestore.collection('custom_characters').doc(characterId).set({
        'id': characterId,
        'userId': userId,
        'name': state.name,
        'gender': state.gender,
        'hairColor': state.hairColor,
        'hairStyle': state.hairStyle,
        'eyeColor': state.eyeColor,
        'skinTone': state.skinTone,
        'bodyType': state.bodyType,
        'clothingStyle': state.clothingStyle,
        'nationality': state.nationality,
        'publicBehavior': state.publicBehavior,
        'speakingStyle': state.speakingStyle,
        'relationshipDynamic': state.relationshipDynamic,
        'systemPrompt': systemPrompt,
        'visualPrompt': visualPrompt,
        'physicalDescription': physicalDescription,
        'isCustom': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(
        isCreating: false,
        createdCharacter: character,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      return false;
    }
  }

  String _getPersonalityDescription() {
    final parts = <String>[];

    if (state.publicBehavior != null) {
      parts.add(publicBehaviors[state.publicBehavior!]['result']!);
    }
    if (state.speakingStyle != null) {
      parts.add(speakingStyles[state.speakingStyle!]['result']!);
    }
    if (state.relationshipDynamic != null) {
      parts.add(relationshipDynamics[state.relationshipDynamic!]['result']!);
    }

    return parts.isEmpty 
        ? 'A caring and supportive companion ready to be your partner.'
        : parts.join('. ') + '.';
  }

  /// Reset the builder state
  void reset() {
    state = const CharacterBuilderState();
  }
}

/// Provider for character builder
final characterBuilderProvider = StateNotifierProvider<CharacterBuilderNotifier, CharacterBuilderState>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CharacterBuilderNotifier(firestore);
});

