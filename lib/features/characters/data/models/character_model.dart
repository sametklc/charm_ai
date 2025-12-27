import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/helpers.dart';
import '../../domain/entities/character_entity.dart';

/// Character model - Data layer representation
class CharacterModel extends CharacterEntity {
  const CharacterModel({
    required super.id,
    required super.name,
    required super.age,
    required super.shortBio,
    required super.personalityDescription,
    required super.systemPrompt,
    required super.avatarUrl,
    super.coverImageUrl,
    required super.voiceStyle,
    required super.traits,
    required super.interests,
    required super.nationality,
    required super.occupation,
    super.isPremium,
    super.isActive,
    super.physicalDescription,
  });

  /// Create from JSON
  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    // Fix avatar URLs by adding https:// prefix if missing
    final avatarUrl = Helpers.fixImageUrl(json['avatarUrl']?.toString() ?? '');
    final coverImageUrl = json['coverImageUrl'] != null 
        ? Helpers.fixImageUrl(json['coverImageUrl']?.toString())
        : null;
    
    return CharacterModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 25,
      shortBio: json['shortBio'] ?? '',
      personalityDescription: json['personalityDescription'] ?? '',
      systemPrompt: json['systemPrompt'] ?? '',
      avatarUrl: avatarUrl,
      coverImageUrl: coverImageUrl,
      voiceStyle: _parseVoiceStyle(json['voiceStyle']),
      traits: _parseTraits(json['traits']),
      interests: List<String>.from(json['interests'] ?? []),
      nationality: json['nationality'] ?? '',
      occupation: json['occupation'] ?? '',
      isPremium: json['isPremium'] ?? false,
      isActive: json['isActive'] ?? true,
      physicalDescription: json['physicalDescription'] ?? '',
    );
  }

  /// Create from Firestore document
  factory CharacterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CharacterModel.fromJson({...data, 'id': doc.id});
  }

  /// Create from entity
  factory CharacterModel.fromEntity(CharacterEntity entity) {
    return CharacterModel(
      id: entity.id,
      name: entity.name,
      age: entity.age,
      shortBio: entity.shortBio,
      personalityDescription: entity.personalityDescription,
      systemPrompt: entity.systemPrompt,
      avatarUrl: entity.avatarUrl,
      coverImageUrl: entity.coverImageUrl,
      voiceStyle: entity.voiceStyle,
      traits: entity.traits,
      interests: entity.interests,
      nationality: entity.nationality,
      occupation: entity.occupation,
      isPremium: entity.isPremium,
      isActive: entity.isActive,
      physicalDescription: entity.physicalDescription,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'shortBio': shortBio,
      'personalityDescription': personalityDescription,
      'systemPrompt': systemPrompt,
      'avatarUrl': avatarUrl,
      'coverImageUrl': coverImageUrl,
      'voiceStyle': voiceStyle.name,
      'traits': traits.map((t) => t.name).toList(),
      'interests': interests,
      'nationality': nationality,
      'occupation': occupation,
      'isPremium': isPremium,
      'isActive': isActive,
      'physicalDescription': physicalDescription,
    };
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  /// Convert to entity
  CharacterEntity toEntity() {
    return CharacterEntity(
      id: id,
      name: name,
      age: age,
      shortBio: shortBio,
      personalityDescription: personalityDescription,
      systemPrompt: systemPrompt,
      avatarUrl: avatarUrl,
      coverImageUrl: coverImageUrl,
      voiceStyle: voiceStyle,
      traits: traits,
      interests: interests,
      nationality: nationality,
      occupation: occupation,
      isPremium: isPremium,
      isActive: isActive,
      physicalDescription: physicalDescription,
    );
  }

  static VoiceStyle _parseVoiceStyle(String? style) {
    if (style == null) return VoiceStyle.soft;
    return VoiceStyle.values.firstWhere(
      (v) => v.name == style,
      orElse: () => VoiceStyle.soft,
    );
  }

  static List<PersonalityTrait> _parseTraits(dynamic traits) {
    if (traits == null) return [];
    if (traits is List) {
      return traits
          .map((t) => PersonalityTrait.values.firstWhere(
                (pt) => pt.name == t.toString(),
                orElse: () => PersonalityTrait.caring,
              ))
          .toList();
    }
    return [];
  }
}

