import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../features/characters/domain/entities/character_entity.dart';

/// Debug-only service to generate and save batch characters for testing
class BatchGeneratorService {
  final Random _random = Random();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _names = [
    'Emma', 'Olivia'
  ];

  final List<String> _personalities = ['shy', 'confident', 'playful', 'intellectual', 'caring'];

  /// Generate and save 2 random characters to Firestore
  Future<void> generateAndSaveBatch(BuildContext context) async {
    try {
      // Generate 2 characters
      for (int i = 0; i < 2; i++) {
        await _generateSingleCharacter();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully generated 2 test characters!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate characters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate a single random character
  Future<void> _generateSingleCharacter() async {
    // Generate random attributes
    final name = _names[_random.nextInt(_names.length)];
    final personality = _personalities[_random.nextInt(_personalities.length)];
    final age = 18 + _random.nextInt(18);

    // Create character entity with placeholder image
    final character = CharacterEntity(
      id: 'debug_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      name: name,
      age: age,
      shortBio: 'A $personality person with creative spirit.',
      personalityDescription: 'I am a $personality person who enjoys art, music, and good conversations.',
      systemPrompt: 'You are $name, a $age year old person. You are $personality and enjoy creative activities. Always stay in character and be engaging.',
      avatarUrl: 'https://picsum.photos/400/400?random=${_random.nextInt(1000)}',
      nationality: 'American',
      occupation: _getRandomOccupation(),
      voiceStyle: VoiceStyle.cheerful,
      traits: [_getPersonalityTrait(personality)],
      interests: _getRandomInterests(),
      physicalDescription: '$age year old person with creative appearance',
    );

    // Save to Firestore
    await _firestore.collection('characters').doc(character.id).set({
      'id': character.id,
      'name': character.name,
      'age': character.age,
      'shortBio': character.shortBio,
      'personalityDescription': character.personalityDescription,
      'systemPrompt': character.systemPrompt,
      'avatarUrl': character.avatarUrl,
      'nationality': character.nationality,
      'occupation': character.occupation,
      'traits': character.traits.map((t) => t.name).toList(),
      'interests': character.interests,
      'physicalDescription': character.physicalDescription,
      'isPredefined': true,
      'isPremium': false,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ Generated character: ${character.name} (${character.id})');
  }

  String _getRandomOccupation() {
    final occupations = [
      'Designer', 'Artist', 'Teacher', 'Engineer', 'Writer', 'Photographer'
    ];
    return occupations[_random.nextInt(occupations.length)];
  }

  PersonalityTrait _getPersonalityTrait(String personality) {
    switch (personality) {
      case 'shy': return PersonalityTrait.shy;
      case 'confident': return PersonalityTrait.confident;
      case 'playful': return PersonalityTrait.playful;
      case 'intellectual': return PersonalityTrait.intellectual;
      case 'caring': return PersonalityTrait.caring;
      default: return PersonalityTrait.caring;
    }
  }

  List<String> _getRandomInterests() {
    final allInterests = [
      'Reading', 'Music', 'Art', 'Cooking', 'Sports', 'Travel'
    ];

    final selectedInterests = <String>[];
    final count = 2 + _random.nextInt(3); // 2-4 interests

    while (selectedInterests.length < count) {
      final interest = allInterests[_random.nextInt(allInterests.length)];
      if (!selectedInterests.contains(interest)) {
        selectedInterests.add(interest);
      }
    }

    return selectedInterests;
  }
}