import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../../media_generation/presentation/providers/media_providers.dart';
import '../../../media_generation/domain/entities/media_entity.dart';
import '../../../chat/presentation/providers/chat_controller.dart';
import '../providers/character_creator_provider.dart';

/// Character Creator Screen - Multi-step form with Firebase Storage upload
class CharacterCreatorScreen extends ConsumerStatefulWidget {
  const CharacterCreatorScreen({super.key});

  @override
  ConsumerState<CharacterCreatorScreen> createState() => _CharacterCreatorScreenState();
}

class _CharacterCreatorScreenState extends ConsumerState<CharacterCreatorScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Reset character creator state when screen is opened
    // This ensures we always start with a fresh form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(characterCreatorProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _createCharacter() async {
    print('🔵 CharacterCreator: _createCharacter called');
    final user = ref.read(currentUserProvider);
    if (user == null) {
      print('❌ CharacterCreator: User is null, cannot create character');
      return;
    }
    
    print('✅ CharacterCreator: User found: ${user.uid}');
    final notifier = ref.read(characterCreatorProvider.notifier);
    final state = ref.read(characterCreatorProvider);
    print('🔵 CharacterCreator: Character name: ${state.name}, gender: ${state.gender}');
    
    notifier.setCreating(true);
    print('✅ CharacterCreator: Creating state set to true');

    try {
      // Step 1: Generate image via API
      print('🔵 CharacterCreator: Step 1 - Building visual prompt...');
      final visualPrompt = notifier.buildVisualPrompt();
      print('✅ CharacterCreator: Visual prompt: "${visualPrompt.substring(0, visualPrompt.length > 100 ? 100 : visualPrompt.length)}${visualPrompt.length > 100 ? "..." : ""}"');
      
      final generateImage = ref.read(generateImageUseCaseProvider);
      print('🔵 CharacterCreator: Calling image generation API...');
      
      final params = ImageGenerationParams(
        prompt: visualPrompt,
        negativePrompt: 'ugly, deformed, noisy, blurry, low quality, distorted face, bad anatomy, cartoon, anime, 3d render',
        width: 768,
        height: 1024,
        model: 'flux-schnell',
        numOutputs: 1,
      );

      final result = await generateImage(userId: user.uid, params: params);
      print('🔵 CharacterCreator: Image generation API call completed');

      await result.fold(
        (failure) async {
          print('❌ CharacterCreator: Image generation failed: ${failure.message}');
          notifier.setCreating(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to generate image: ${failure.message}')),
            );
          }
        },
        (media) async {
          print('✅ CharacterCreator: Image generation successful');
          final tempUrl = media.firstImageUrl;
          if (tempUrl == null) {
            print('❌ CharacterCreator: No image URL returned from generation');
            notifier.setCreating(false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No image was generated')),
              );
            }
            return;
          }
          
          print('✅ CharacterCreator: Temporary image URL received: $tempUrl');

          // Step 2: Upload to Firebase Storage
          print('🔵 CharacterCreator: Step 2 - Uploading to Firebase Storage...');
          String? permanentUrl;
          String storagePath;
          
          try {
            final storageService = ref.read(storageServiceProvider);
            storagePath = storageService.generateCharacterAvatarPath(user.uid);
            
            print('🔵 CharacterCreator: Storage path generated: $storagePath');
            print('🔵 CharacterCreator: Starting storage upload from $tempUrl to $storagePath');
            
            permanentUrl = await storageService.downloadAndUpload(
              sourceUrl: tempUrl,
              storagePath: storagePath,
            );

            if (permanentUrl == null) {
              notifier.setCreating(false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to save image to storage. Please check your internet connection and try again.'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
              return;
            }
            
            print('✅ CharacterCreator: Image uploaded successfully. Permanent URL: $permanentUrl');
          } catch (e, stackTrace) {
            print('❌ CharacterCreator: Storage upload error: $e');
            print('Stack trace: $stackTrace');
            notifier.setCreating(false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Storage error: ${e.toString()}'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          // Step 3: Save to Firestore
          print('🔵 CharacterCreator: Step 3 - Saving character to Firestore...');
          try {
            print('🔵 CharacterCreator: Calling _saveCharacterToFirestore...');
            final character = await _saveCharacterToFirestore(
              userId: user.uid,
              avatarUrl: permanentUrl!,
              storagePath: storagePath,
            );

            if (character == null) {
              print('❌ CharacterCreator: _saveCharacterToFirestore returned null');
              notifier.setCreating(false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save character')),
                );
              }
              return;
            }

            print('✅ CharacterCreator: Character saved successfully. ID: ${character.id}, Name: ${character.name}');
            print('🔵 CharacterCreator: Step 4 - Navigating to chat...');
            
            // Reset state BEFORE navigation
            notifier.setCreating(false);
            notifier.reset();
            
            // CRITICAL: Also reset ChatController to avoid showing old messages
            ref.read(chatControllerProvider.notifier).resetConversation();
            print('✅ CharacterCreator: All states reset completed');

            if (mounted) {
              // Step 4: Navigate to ChatScreen with character and NO conversationId
              // This ensures a new conversation will be created for this character
              print('🔵 CharacterCreator: Pushing to chat screen with character: ${character.name}');
              await Navigator.pushNamed(
                context, 
                '/chat', 
                arguments: {
                  'character': character,
                  'conversationId': null, // CRITICAL: Force new conversation
                },
              );
              print('✅ CharacterCreator: Navigation to chat completed');
            } else {
              print('❌ CharacterCreator: Widget not mounted, cannot navigate');
            }
          } catch (e, stackTrace) {
            print('❌ CharacterCreator: Error saving character to Firestore: $e');
            print('Stack trace: $stackTrace');
            notifier.setCreating(false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving character: $e')),
              );
            }
          }
        },
      );
    } catch (e) {
      notifier.setCreating(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<CharacterEntity?> _saveCharacterToFirestore({
    required String userId,
    required String avatarUrl,
    required String storagePath,
  }) async {
    print('🔵 CharacterCreator: _saveCharacterToFirestore called');
    print('🔵 CharacterCreator: userId: $userId, avatarUrl: $avatarUrl, storagePath: $storagePath');
    
    final state = ref.read(characterCreatorProvider);
    final notifier = ref.read(characterCreatorProvider.notifier);
    final firestore = ref.read(firestoreProvider);

    final characterId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    print('🔵 CharacterCreator: Generated characterId: $characterId');
    
    final systemPrompt = notifier.buildSystemPrompt();
    final physicalDescription = notifier.buildPhysicalDescription();
    print('🔵 CharacterCreator: System prompt length: ${systemPrompt.length}');
    print('🔵 CharacterCreator: Physical description length: ${physicalDescription.length}');

    // Determine personality traits
    final traits = <PersonalityTrait>[];
    if (state.publicBehavior == 0) traits.add(PersonalityTrait.shy);
    if (state.publicBehavior == 1) traits.add(PersonalityTrait.confident);
    if (state.publicBehavior == 3) traits.add(PersonalityTrait.flirty);
    if (state.publicBehavior == 4) traits.add(PersonalityTrait.caring);
    if (state.speakingStyle == 2) traits.add(PersonalityTrait.romantic);
    if (state.speakingStyle == 3) traits.add(PersonalityTrait.playful);
    if (traits.isEmpty) traits.add(PersonalityTrait.caring);
    print('🔵 CharacterCreator: Personality traits: ${traits.map((t) => t.name).join(", ")}');

    try {
      // Save to Firestore characters collection
      print('🔵 CharacterCreator: Saving character document to Firestore at characters/$characterId');
      await firestore.collection('characters').doc(characterId).set({
        'id': characterId,
        'userId': userId,
        'name': state.name,
        'age': 25,
        'gender': state.gender,
        'shortBio': 'Your Custom Companion ✨',
        'personalityDescription': _getPersonalityDescription(state),
        'systemPrompt': systemPrompt,
        'avatarUrl': avatarUrl,
        'storagePath': storagePath,
        'voiceStyle': VoiceStyle.soft.name,
        'traits': traits.map((t) => t.name).toList(),
        'interests': ['Spending time with you', 'Deep conversations', 'Adventures'],
        'nationality': state.nationality.isEmpty ? 'Unknown' : state.nationality,
        'occupation': 'Your Companion',
        'physicalDescription': physicalDescription,
        'hairColor': state.hairColor,
        'hairStyle': state.hairStyle,
        'eyeColor': state.eyeColor,
        'skinTone': state.skinTone,
        'bodyType': state.bodyType,
        'clothingStyle': state.clothingStyle,
        'isCustom': true,
        'isPremium': false,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ CharacterCreator: Character document saved to Firestore');

      // Also create a conversation for this character
      print('🔵 CharacterCreator: Creating conversation for character...');
      final conversationRef = firestore.collection('conversations').doc();
      final conversationId = conversationRef.id;
      print('🔵 CharacterCreator: Conversation ID: $conversationId');
      
      await conversationRef.set({
        'userId': userId,
        'characterId': characterId,
        'characterName': state.name,
        'characterAvatar': avatarUrl,
        'lastMessage': 'Say hi to ${state.name}! 👋',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isCustom': true,
      });
      print('✅ CharacterCreator: Conversation created in Firestore');

      // Return the character entity
      print('🔵 CharacterCreator: Creating CharacterEntity object...');
      final characterEntity = CharacterEntity(
        id: characterId,
        name: state.name,
        age: 25,
        shortBio: 'Your Custom Companion ✨',
        personalityDescription: _getPersonalityDescription(state),
        systemPrompt: systemPrompt,
        avatarUrl: avatarUrl,
        voiceStyle: VoiceStyle.soft,
        traits: traits,
        interests: const ['Spending time with you', 'Deep conversations', 'Adventures'],
        nationality: state.nationality.isEmpty ? 'Unknown' : state.nationality,
        occupation: 'Your Companion',
        physicalDescription: physicalDescription,
      );
      print('✅ CharacterCreator: CharacterEntity created successfully: ${characterEntity.name} (${characterEntity.id})');
      return characterEntity;
    } catch (e, stackTrace) {
      print('❌ CharacterCreator: Error saving character to Firestore: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  String _getPersonalityDescription(CharacterCreatorState state) {
    final parts = <String>[];
    if (state.publicBehavior != null) {
      parts.add(CharacterCreatorNotifier.publicBehaviors[state.publicBehavior!]['result']!);
    }
    if (state.speakingStyle != null) {
      parts.add(CharacterCreatorNotifier.speakingStyles[state.speakingStyle!]['result']!);
    }
    if (state.relationshipDynamic != null) {
      parts.add(CharacterCreatorNotifier.relationshipDynamics[state.relationshipDynamic!]['result']!);
    }
    return parts.isEmpty
        ? 'A caring and supportive companion ready to be your partner.'
        : '${parts.join('. ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(characterCreatorProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.backgroundDark, AppColors.surfaceDark]
              : [const Color(0xFFF0E6FF), const Color(0xFFFFF0F5)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Create Your Companion ✨',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepTitle(),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index <= _currentStep;
                  final isCurrent = index == _currentStep;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: isActive
                            ? (isCurrent ? AppColors.secondary : AppColors.primary)
                            : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
                      ),
                    ).animate(target: isActive ? 1 : 0).scaleX(
                          begin: 0.5,
                          duration: 300.ms,
                        ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stepLabel('Look', 0, isDark),
                  _stepLabel('Soul', 1, isDark),
                  _stepLabel('Create', 2, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PhysicalIdentityStep(onNext: _nextStep),
                  _PersonalityQuizStep(onNext: _nextStep, onBack: _previousStep),
                  _FinalizeStep(
                    onBack: _previousStep,
                    onCreate: _createCharacter,
                    isCreating: state.isCreating,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Step 1: Define their appearance';
      case 1:
        return 'Step 2: Shape their personality';
      case 2:
        return 'Step 3: Bring them to life!';
      default:
        return '';
    }
  }

  Widget _stepLabel(String text, int step, bool isDark) {
    final isActive = step <= _currentStep;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        color: isActive
            ? (step == _currentStep ? AppColors.secondary : AppColors.primary)
            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
      ),
    );
  }
}

/// Step 1: Physical Identity
class _PhysicalIdentityStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const _PhysicalIdentityStep({required this.onNext});

  @override
  ConsumerState<_PhysicalIdentityStep> createState() => _PhysicalIdentityStepState();
}

class _PhysicalIdentityStepState extends ConsumerState<_PhysicalIdentityStep> {
  final _nameController = TextEditingController();
  final _nationalityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(characterCreatorProvider);
    _nameController.text = state.name;
    _nationalityController.text = state.nationality;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    final state = ref.watch(characterCreatorProvider);
    return state.name.isNotEmpty && state.gender != null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(characterCreatorProvider);
    final notifier = ref.read(characterCreatorProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name input
          _buildSectionTitle('Name', isDark),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: notifier.setName,
            decoration: _inputDecoration('Enter a name...', isDark),
          ),
          const SizedBox(height: 20),

          // Gender selection
          _buildSectionTitle('Gender', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderButton(
                  label: 'Female',
                  icon: Icons.female,
                  isSelected: state.gender == 'Female',
                  onTap: () => notifier.setGender('Female'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderButton(
                  label: 'Male',
                  icon: Icons.male,
                  isSelected: state.gender == 'Male',
                  onTap: () => notifier.setGender('Male'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Appearance dropdowns
          _buildSectionTitle('Hair Color', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.hairColor,
            items: CharacterCreatorNotifier.hairColors,
            onChanged: notifier.setHairColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Hair Style', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.hairStyle,
            items: CharacterCreatorNotifier.hairStyles,
            onChanged: notifier.setHairStyle,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Eye Color', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.eyeColor,
            items: CharacterCreatorNotifier.eyeColors,
            onChanged: notifier.setEyeColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Skin Tone', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.skinTone,
            items: CharacterCreatorNotifier.skinTones,
            onChanged: notifier.setSkinTone,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Body Type', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.bodyType,
            items: CharacterCreatorNotifier.bodyTypes,
            onChanged: notifier.setBodyType,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Clothing Style', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.clothingStyle,
            items: CharacterCreatorNotifier.clothingStyles,
            onChanged: notifier.setClothingStyle,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Origin/Nationality', isDark),
          const SizedBox(height: 8),
          TextField(
            controller: _nationalityController,
            onChanged: notifier.setNationality,
            decoration: _inputDecoration('e.g., Japanese, Brazilian...', isDark),
          ),
          const SizedBox(height: 32),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceed() ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
              ),
              child: const Text(
                'Continue to Personality',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            'Select...',
            style: TextStyle(color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
          ),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Gender button
class _GenderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2: Personality Quiz
class _PersonalityQuizStep extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PersonalityQuizStep({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(characterCreatorProvider);
    final notifier = ref.read(characterCreatorProvider.notifier);

    final canProceed = state.publicBehavior != null &&
        state.speakingStyle != null &&
        state.relationshipDynamic != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuizQuestion(
            question: 'How does your partner behave in public?',
            options: CharacterCreatorNotifier.publicBehaviors,
            selectedIndex: state.publicBehavior,
            onSelect: notifier.setPublicBehavior,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          _QuizQuestion(
            question: 'How do they speak to you?',
            options: CharacterCreatorNotifier.speakingStyles,
            selectedIndex: state.speakingStyle,
            onSelect: notifier.setSpeakingStyle,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          _QuizQuestion(
            question: 'What is the relationship dynamic?',
            options: CharacterCreatorNotifier.relationshipDynamics,
            selectedIndex: state.relationshipDynamic,
            onSelect: notifier.setRelationshipDynamic,
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: canProceed ? onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Continue to Create',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Quiz question
class _QuizQuestion extends StatelessWidget {
  final String question;
  final List<Map<String, String>> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isDark;

  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(options.length, (index) {
          final option = options[index];
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.15)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option['label']!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Step 3: Finalize
class _FinalizeStep extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final bool isCreating;

  const _FinalizeStep({
    required this.onBack,
    required this.onCreate,
    required this.isCreating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(characterCreatorProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Preview card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    state.gender == 'Male' ? Icons.face_6 : Icons.face_3,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  state.name.isEmpty ? 'Your Companion' : state.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                _buildSummaryRow('Gender', state.gender ?? 'Not set', isDark),
                _buildSummaryRow('Hair', '${state.hairColor ?? '?'} ${state.hairStyle ?? '?'}', isDark),
                _buildSummaryRow('Eyes', state.eyeColor ?? 'Not set', isDark),
                _buildSummaryRow('Style', state.clothingStyle ?? 'Not set', isDark),
                _buildSummaryRow('Origin', state.nationality.isEmpty ? 'Not set' : state.nationality, isDark),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your companion will be generated with AI and saved permanently. This may take a moment.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isCreating ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isCreating ? null : onCreate,
                  icon: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(isCreating ? 'Creating...' : 'Bring to Life! ✨'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

