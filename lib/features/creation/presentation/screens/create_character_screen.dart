import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/character_builder_provider.dart';

/// Create Character Screen - Multi-step character builder
class CreateCharacterScreen extends ConsumerStatefulWidget {
  const CreateCharacterScreen({super.key});

  @override
  ConsumerState<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends ConsumerState<CreateCharacterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

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
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final success = await ref.read(characterBuilderProvider.notifier).createCharacter(user.uid);
    
    if (success && mounted) {
      final character = ref.read(characterBuilderProvider).createdCharacter;
      if (character != null) {
        // Navigate to chat with the new character
        Navigator.pushNamed(context, '/chat', arguments: character);
        // Reset the builder
        ref.read(characterBuilderProvider.notifier).reset();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create character. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Watch for state changes (used for progress indicators)
    ref.watch(characterBuilderProvider);

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
                  _FinalizeStep(onBack: _previousStep, onCreate: _createCharacter),
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
    final state = ref.read(characterBuilderProvider);
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
    final state = ref.watch(characterBuilderProvider);
    return state.name.isNotEmpty && state.gender != null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(characterBuilderProvider);
    final notifier = ref.read(characterBuilderProvider.notifier);

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

          // Hair Color
          _buildSectionTitle('Hair Color', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.hairColor,
            items: CharacterBuilderNotifier.hairColors,
            onChanged: notifier.setHairColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Hair Style
          _buildSectionTitle('Hair Style', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.hairStyle,
            items: CharacterBuilderNotifier.hairStyles,
            onChanged: notifier.setHairStyle,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Eye Color
          _buildSectionTitle('Eye Color', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.eyeColor,
            items: CharacterBuilderNotifier.eyeColors,
            onChanged: notifier.setEyeColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Skin Tone
          _buildSectionTitle('Skin Tone', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.skinTone,
            items: CharacterBuilderNotifier.skinTones,
            onChanged: notifier.setSkinTone,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Body Type
          _buildSectionTitle('Body Type', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.bodyType,
            items: CharacterBuilderNotifier.bodyTypes,
            onChanged: notifier.setBodyType,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Clothing Style
          _buildSectionTitle('Clothing Style', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: state.clothingStyle,
            items: CharacterBuilderNotifier.clothingStyles,
            onChanged: notifier.setClothingStyle,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Nationality
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

/// Gender selection button
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
    final state = ref.watch(characterBuilderProvider);
    final notifier = ref.read(characterBuilderProvider.notifier);

    final canProceed = state.publicBehavior != null &&
        state.speakingStyle != null &&
        state.relationshipDynamic != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question 1
          _QuizQuestion(
            question: 'How does your partner behave in public?',
            options: CharacterBuilderNotifier.publicBehaviors,
            selectedIndex: state.publicBehavior,
            onSelect: notifier.setPublicBehavior,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Question 2
          _QuizQuestion(
            question: 'How do they speak to you?',
            options: CharacterBuilderNotifier.speakingStyles,
            selectedIndex: state.speakingStyle,
            onSelect: notifier.setSpeakingStyle,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Question 3
          _QuizQuestion(
            question: 'What is the relationship dynamic?',
            options: CharacterBuilderNotifier.relationshipDynamics,
            selectedIndex: state.relationshipDynamic,
            onSelect: notifier.setRelationshipDynamic,
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          // Navigation buttons
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

/// Quiz question widget
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

  const _FinalizeStep({required this.onBack, required this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(characterBuilderProvider);

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
                // Character preview icon
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

                // Summary
                _buildSummaryRow('Gender', state.gender ?? 'Not set', isDark),
                _buildSummaryRow('Hair', '${state.hairColor ?? '?'} ${state.hairStyle ?? '?'}', isDark),
                _buildSummaryRow('Eyes', state.eyeColor ?? 'Not set', isDark),
                _buildSummaryRow('Style', state.clothingStyle ?? 'Not set', isDark),
                _buildSummaryRow('Origin', state.nationality.isEmpty ? 'Not set' : state.nationality, isDark),
                const SizedBox(height: 16),

                // Personality summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personality Preview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getPersonalitySummary(state),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 24),

          // Info text
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
                    'Your companion will be generated with AI. The first image may take a few moments.',
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

          // Navigation buttons
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
                child: ElevatedButton.icon(
                  onPressed: state.isCreating ? null : onCreate,
                  icon: state.isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(state.isCreating ? 'Creating...' : 'Bring to Life! ✨'),
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

  String _getPersonalitySummary(CharacterBuilderState state) {
    final parts = <String>[];

    if (state.publicBehavior != null) {
      parts.add(CharacterBuilderNotifier.publicBehaviors[state.publicBehavior!]['result']!);
    }
    if (state.speakingStyle != null) {
      parts.add(CharacterBuilderNotifier.speakingStyles[state.speakingStyle!]['result']!);
    }
    if (state.relationshipDynamic != null) {
      parts.add(CharacterBuilderNotifier.relationshipDynamics[state.relationshipDynamic!]['result']!);
    }

    if (parts.isEmpty) return 'Select personality options to see a preview.';
    return parts.join(', ');
  }
}

