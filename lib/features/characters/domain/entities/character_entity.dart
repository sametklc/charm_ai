import 'package:equatable/equatable.dart';

/// Character personality traits
enum PersonalityTrait {
  shy,
  confident,
  romantic,
  playful,
  intellectual,
  adventurous,
  caring,
  mysterious,
  artistic,
  sporty,
  nerdy,
  flirty,
}

/// Voice style for future TTS integration
enum VoiceStyle {
  soft,
  energetic,
  sultry,
  cheerful,
  calm,
  playful,
}

/// Character entity - Core business object for AI companions
class CharacterEntity extends Equatable {
  final String id;
  final String name;
  final int age;
  final String shortBio;
  final String personalityDescription;
  final String systemPrompt;
  final String avatarUrl;
  final String? coverImageUrl;
  final VoiceStyle voiceStyle;
  final List<PersonalityTrait> traits;
  final List<String> interests;
  final String nationality;
  final String occupation;
  final bool isPremium;
  final bool isActive;
  
  /// Physical description for AI image generation (selfies)
  final String physicalDescription;

  const CharacterEntity({
    required this.id,
    required this.name,
    required this.age,
    required this.shortBio,
    required this.personalityDescription,
    required this.systemPrompt,
    required this.avatarUrl,
    this.coverImageUrl,
    required this.voiceStyle,
    required this.traits,
    required this.interests,
    required this.nationality,
    required this.occupation,
    this.isPremium = false,
    this.isActive = true,
    this.physicalDescription = '',
  });
  
  /// Generate selfie prompt for image generation
  String get selfiePrompt {
    if (physicalDescription.isEmpty) {
      return 'A beautiful selfie photo of a young woman, smiling warmly at camera, natural lighting, high quality, 4k, realistic';
    }
    return 'A selfie photo of $physicalDescription, looking at camera with a warm smile, natural lighting, high quality, 4k, realistic, Instagram style';
  }

  /// Get primary trait
  PersonalityTrait? get primaryTrait => traits.isNotEmpty ? traits.first : null;

  /// Get trait names as strings
  List<String> get traitNames => traits.map((t) => t.name).toList();

  /// Get formatted age string
  String get ageString => '$age years old';

  /// Get display subtitle
  String get subtitle => '$occupation • $nationality';

  CharacterEntity copyWith({
    String? id,
    String? name,
    int? age,
    String? shortBio,
    String? personalityDescription,
    String? systemPrompt,
    String? avatarUrl,
    String? coverImageUrl,
    VoiceStyle? voiceStyle,
    List<PersonalityTrait>? traits,
    List<String>? interests,
    String? nationality,
    String? occupation,
    bool? isPremium,
    bool? isActive,
    String? physicalDescription,
  }) {
    return CharacterEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      shortBio: shortBio ?? this.shortBio,
      personalityDescription: personalityDescription ?? this.personalityDescription,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      traits: traits ?? this.traits,
      interests: interests ?? this.interests,
      nationality: nationality ?? this.nationality,
      occupation: occupation ?? this.occupation,
      isPremium: isPremium ?? this.isPremium,
      isActive: isActive ?? this.isActive,
      physicalDescription: physicalDescription ?? this.physicalDescription,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        age,
        shortBio,
        personalityDescription,
        systemPrompt,
        avatarUrl,
        coverImageUrl,
        voiceStyle,
        traits,
        interests,
        nationality,
        occupation,
        isPremium,
        isActive,
        physicalDescription,
      ];
}

