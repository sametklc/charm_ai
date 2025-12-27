import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/data/repositories/predefined_characters.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../providers/match_providers.dart';

/// Swipe Screen - Tinder-like card swiping interface
class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  late CardSwiperController _swiperController;
  final List<CharacterEntity> _characters = [];
  bool _showMatch = false;
  CharacterEntity? _matchedCharacter;

  @override
  void initState() {
    super.initState();
    _swiperController = CardSwiperController();
    _loadCharacters();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  void _loadCharacters() {
    // Load predefined characters in random order
    final allCharacters = List<CharacterEntity>.from(PredefinedCharacters.all);
    allCharacters.shuffle();
    setState(() {
      _characters.clear();
      _characters.addAll(allCharacters);
    });
  }

  Future<void> _onSwipeRight(CharacterEntity character) async {
    // Show match animation
    setState(() {
      _matchedCharacter = character;
      _showMatch = true;
    });

    // Save to user's matches in Firestore
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(saveMatchProvider)(user.uid, character.id);
    }
  }

  void _onSwipeLeft(CharacterEntity character) {
    // Just pass, no action needed
  }

  void _dismissMatch() {
    setState(() {
      _showMatch = false;
      _matchedCharacter = null;
    });
  }

  void _startChat() {
    if (_matchedCharacter == null) return;
    
    _dismissMatch();
    Navigator.pushNamed(context, '/chat', arguments: _matchedCharacter);
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (previousIndex >= _characters.length) return false;
    
    final character = _characters[previousIndex];
    
    if (direction == CardSwiperDirection.right) {
      _onSwipeRight(character);
    } else if (direction == CardSwiperDirection.left) {
      _onSwipeLeft(character);
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [AppColors.backgroundDark, AppColors.surfaceDark]
                  : [const Color(0xFFFDF2F8), const Color(0xFFF8F0FF)],
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              // Header text
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Find Your Match 💕',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Swipe right to match, left to pass',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card swiper
              Expanded(
                child: _characters.isEmpty
                    ? _buildEmptyState(isDark)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CardSwiper(
                          controller: _swiperController,
                          cardsCount: _characters.length,
                          numberOfCardsDisplayed: 3,
                          backCardOffset: const Offset(0, 40.0),
                          padding: const EdgeInsets.all(24),
                          onSwipe: _onSwipe,
                          onEnd: () {
                            // Reload characters when all are swiped
                            _loadCharacters();
                          },
                          cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                            return _SwipeCard(
                              character: _characters[index],
                              swipeProgress: percentThresholdX.toDouble(),
                            );
                          },
                        ),
                      ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Pass button
                    _ActionButton(
                      icon: Icons.close_rounded,
                      color: AppColors.error,
                      size: 56,
                      onTap: () => _swiperController.swipe(CardSwiperDirection.left),
                    ),
                    // Undo button
                    _ActionButton(
                      icon: Icons.refresh_rounded,
                      color: Colors.amber,
                      size: 48,
                      onTap: () => _swiperController.undo(),
                    ),
                    // Like button
                    _ActionButton(
                      icon: Icons.favorite_rounded,
                      color: AppColors.primary,
                      size: 56,
                      onTap: () => _swiperController.swipe(CardSwiperDirection.right),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Match overlay
        if (_showMatch && _matchedCharacter != null)
          _MatchOverlay(
            character: _matchedCharacter!,
            onDismiss: _dismissMatch,
            onStartChat: _startChat,
          ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 80,
            color: AppColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No more cards!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for more matches',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe card widget
class _SwipeCard extends StatelessWidget {
  final CharacterEntity character;
  final double swipeProgress;

  const _SwipeCard({
    required this.character,
    required this.swipeProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CachedNetworkImage(
              imageUrl: character.avatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                child: const Icon(Icons.person, size: 80),
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
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),

            // Like/Nope stamps
            if (swipeProgress != 0)
              Positioned(
                top: 40,
                left: swipeProgress > 0 ? 20 : null,
                right: swipeProgress < 0 ? 20 : null,
                child: Transform.rotate(
                  angle: swipeProgress > 0 ? -0.3 : 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: swipeProgress > 0 ? AppColors.success : AppColors.error,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      swipeProgress > 0 ? 'LIKE' : 'NOPE',
                      style: TextStyle(
                        color: swipeProgress > 0 ? AppColors.success : AppColors.error,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),


            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name and age
                  Row(
                    children: [
                      Text(
                        '${character.name}, ${character.age}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    character.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bio
                  Text(
                    character.shortBio,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Traits
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: character.traits.take(3).map((trait) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          trait.name[0].toUpperCase() + trait.name.substring(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Match overlay animation
class _MatchOverlay extends StatelessWidget {
  final CharacterEntity character;
  final VoidCallback onDismiss;
  final VoidCallback onStartChat;

  const _MatchOverlay({
    required this.character,
    required this.onDismiss,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Match text
              Text(
                "It's a Match! 💕",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: 600.ms,
              ),
              const SizedBox(height: 8),
              Text(
                'You and ${character.name} liked each other!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),

              // Character avatar
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: character.avatarUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).scale(
                begin: const Offset(0.8, 0.8),
                curve: Curves.elasticOut,
                duration: 500.ms,
              ),
              const SizedBox(height: 16),
              Text(
                character.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 40),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Keep swiping
                  OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Keep Swiping'),
                  ),
                  const SizedBox(width: 16),
                  // Say hi button
                  ElevatedButton.icon(
                    onPressed: onStartChat,
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Say Hi! 👋'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

