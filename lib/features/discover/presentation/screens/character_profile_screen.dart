import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Character Profile Screen - Premium dating app style profile view
class CharacterProfileScreen extends ConsumerStatefulWidget {
  final CharacterEntity character;

  const CharacterProfileScreen({
    super.key,
    required this.character,
  });

  @override
  ConsumerState<CharacterProfileScreen> createState() => _CharacterProfileScreenState();
}

class _CharacterProfileScreenState extends ConsumerState<CharacterProfileScreen> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero image with SliverAppBar
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.6,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  CachedNetworkImage(
                    imageUrl: widget.character.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.person, size: 100, color: Colors.grey),
                    ),
                  ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.5, 0.7, 0.85, 1.0],
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),

          // Content section (bottom sheet style)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and age
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.character.name}, ${widget.character.age}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 8),

                  // Subtitle/bio
                  Text(
                    widget.character.shortBio,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                  const SizedBox(height: 24),

                  // About section
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 12),

                  // Personality description
                  GestureDetector(
                    onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        widget.character.personalityDescription,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          height: 1.6,
                        ),
                        maxLines: _isDescriptionExpanded ? null : 3,
                        overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),

                  // Read more/less button
                  GestureDetector(
                    onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                    child: Text(
                      _isDescriptionExpanded ? 'Show Less' : 'Read More',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 24),

                  // Interests/Tags section
                  Text(
                    'Interests',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                  const SizedBox(height: 12),

                  // Interest tags
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.character.interests.map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          interest,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),

                  // Personality traits
                  if (widget.character.traits.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Personality',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: widget.character.traits.map((trait) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            trait.name[0].toUpperCase() + trait.name.substring(1),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
                  ],

                  const SizedBox(height: 40),

                  // Action buttons
                  Row(
                    children: [
                      // Back button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: isDark ? Colors.white30 : Colors.black26,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Message button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _startChat(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'Message',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      // Create conversation
      final conversationRef = ref.read(firestoreProvider).collection('conversations').doc();
      await conversationRef.set({
        'userId': user.uid,
        'characterId': widget.character.id,
        'characterName': widget.character.name,
        'characterAvatar': widget.character.avatarUrl,
        'lastMessage': 'Say hi to ${widget.character.name}! 👋',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isCustom': false,
      });

      if (context.mounted) {
        // Navigate to chat
        Navigator.pushNamed(context, '/chat', arguments: widget.character);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
