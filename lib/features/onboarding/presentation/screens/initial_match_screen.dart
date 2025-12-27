import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../../../app.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/domain/entities/character_entity.dart';

/// Initial Match Screen - Shown after login for swipe-first onboarding
class InitialMatchScreen extends ConsumerStatefulWidget {
  const InitialMatchScreen({super.key});

  @override
  ConsumerState<InitialMatchScreen> createState() => _InitialMatchScreenState();
}

class _InitialMatchScreenState extends ConsumerState<InitialMatchScreen> {
  late CardSwiperController _swiperController;
  final List<CharacterEntity> _characters = [];
  int _matchCount = 0;
  int _swipedCount = 0; // Track total swipes (left + right)
  bool _showMatch = false;
  CharacterEntity? _matchedCharacter;
  bool _isNavigating = false;
  bool _isLoading = true;
  final Random _random = Random();

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

  Future<void> _loadCharacters() async {
    print('🔵 InitialMatchScreen: _loadCharacters called');
    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = ref.read(firestoreProvider);
      print('🔵 InitialMatchScreen: Firestore instance obtained');
      
      // Get all active characters from Firebase
      // Use same query as discover screen - only filter by isPredefined, then filter isActive client-side
      print('🔵 InitialMatchScreen: Querying Firebase for characters...');
      final snapshot = await firestore
          .collection('characters')
          .where('isPredefined', isEqualTo: true)
          .get();

      print('🔵 InitialMatchScreen: Firebase query completed. Found ${snapshot.docs.length} documents');

      final allCharacters = <CharacterEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Only include active characters (client-side filter)
        final isActive = data['isActive'] ?? true;
        if (!isActive) {
          print('⏭️ InitialMatchScreen: Skipping inactive character ${doc.id}');
          continue;
        }
        
        print('🔵 InitialMatchScreen: Processing character ${doc.id} - Name: ${data['name'] ?? 'Unknown'}');
        
        try {
          final character = CharacterEntity(
            id: doc.id,
            name: data['name'] ?? '',
            age: data['age'] ?? 25,
            shortBio: data['shortBio'] ?? '',
            personalityDescription: data['personalityDescription'] ?? '',
            systemPrompt: data['systemPrompt'] ?? '',
            avatarUrl: data['avatarUrl'] ?? '',
            coverImageUrl: data['coverImageUrl'],
            voiceStyle: VoiceStyle.values.firstWhere(
              (v) => v.name == data['voiceStyle'],
              orElse: () => VoiceStyle.cheerful,
            ),
            traits: (data['traits'] as List<dynamic>?)
                    ?.map((t) => PersonalityTrait.values.firstWhere(
                          (pt) => pt.name == t,
                          orElse: () => PersonalityTrait.caring,
                        ))
                    .toList() ??
                [],
            interests: (data['interests'] as List<dynamic>?)
                    ?.map((i) => i.toString())
                    .toList() ??
                [],
            nationality: data['nationality'] ?? '',
            occupation: data['occupation'] ?? '',
            isPremium: data['isPremium'] ?? false,
            isActive: true,
            physicalDescription: data['physicalDescription'] ?? '',
          );
          allCharacters.add(character);
          print('✅ InitialMatchScreen: Successfully added character ${character.name}');
        } catch (e, stackTrace) {
          print('❌ InitialMatchScreen: Error parsing character ${doc.id}: $e');
          print('Stack trace: $stackTrace');
        }
      }

      print('✅ InitialMatchScreen: Total characters loaded: ${allCharacters.length}');

      // Shuffle randomly
      if (allCharacters.isNotEmpty) {
        allCharacters.shuffle(_random);
        print('🔵 InitialMatchScreen: Characters shuffled');
      } else {
        print('⚠️ InitialMatchScreen: No characters found in Firebase!');
      }

      if (mounted) {
        setState(() {
          _characters.clear();
          _characters.addAll(allCharacters);
          _isLoading = false;
        });
        print('✅ InitialMatchScreen: State updated. Characters count: ${_characters.length}, isLoading: $_isLoading');
      }
    } catch (e, stackTrace) {
      print('❌ InitialMatchScreen: Error loading characters: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('⚠️ InitialMatchScreen: Set isLoading to false due to error');
      }
    }
  }

  Future<void> _reshuffleCharacters() async {
    // Reload and reshuffle characters from Firebase
    await _loadCharacters();
    setState(() {
      _swipedCount = 0;
    });
  }

  Future<void> _onSwipeRight(CharacterEntity character) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final firestore = ref.read(firestoreProvider);

    try {
      // Create conversation in Firestore
      final conversationRef = firestore.collection('conversations').doc();
      await conversationRef.set({
        'userId': user.uid,
        'characterId': character.id,
        'characterName': character.name,
        'characterAvatar': character.avatarUrl,
        'lastMessage': 'Say hi to ${character.name}! 👋',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isCustom': false,
      });

      setState(() {
        _matchCount++;
        _swipedCount++;
      });

      // Show match animation - this is now the trigger to complete onboarding
      setState(() {
        _matchedCharacter = character;
        _showMatch = true;
      });

      // DO NOT navigate automatically - user must click "Let's Start Chatting"
    } catch (e) {
      // Silent fail - don't show error to user during onboarding
      print('Failed to save match: $e');
      setState(() => _swipedCount++);
    }
  }

  void _onSwipeLeft(CharacterEntity character) {
    setState(() => _swipedCount++);

    // If we've swiped through all characters, reshuffle and continue
    if (_swipedCount >= _characters.length) {
      _reshuffleCharacters();
    }
  }

  void _dismissMatch() {
    setState(() {
      _showMatch = false;
      _matchedCharacter = null;
    });
  }

  Future<void> _goToApp() async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    // Mark onboarding as completed
    await setOnboardingCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
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

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [const Color(0xFFFDF2F8), const Color(0xFFEDE9FE)],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Find Your Match 💕',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ).animate().fadeIn().slideY(begin: -0.3),
                      const SizedBox(height: 8),
                      Text(
                        'Swipe right on characters you like',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_matchCount matches',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),

                // Card swiper
                Expanded(
                  child: _isLoading || _characters.isEmpty
                      ? _buildEmptyState(isDark)
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: CardSwiper(
                            controller: _swiperController,
                            cardsCount: _characters.length,
                            numberOfCardsDisplayed: _characters.length > 3 ? 3 : _characters.length,
                            backCardOffset: const Offset(0, 40.0),
                            padding: const EdgeInsets.all(16),
                            onSwipe: _onSwipe,
                            onEnd: () {
                              // Loop back to first card when all are swiped
                              _reshuffleCharacters();
                            },
                            cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                              if (index >= _characters.length) {
                                return const SizedBox.shrink();
                              }
                              return _SwipeCard(
                                character: _characters[index],
                                swipeProgress: percentThresholdX.toDouble(),
                              );
                            },
                          ),
                        ),
                ),

                // Action buttons (always show)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionButton(
                        icon: Icons.close_rounded,
                        color: AppColors.error,
                        size: 60,
                        onTap: () => _swiperController.swipe(CardSwiperDirection.left),
                      ),
                      _ActionButton(
                        icon: Icons.favorite_rounded,
                        color: AppColors.primary,
                        size: 60,
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
              matchCount: _matchCount,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isLoading ? Icons.favorite_border_rounded : Icons.search_off_rounded,
            size: 80,
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _isLoading 
                ? 'Loading characters...' 
                : 'No characters found',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                color: AppColors.surface,
                child: const Center(child: CircularProgressIndicator()),
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
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.95),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),

            // Like/Nope stamps
            if (swipeProgress != 0)
              Positioned(
                top: 50,
                left: swipeProgress > 0 ? 30 : null,
                right: swipeProgress < 0 ? 30 : null,
                child: Transform.rotate(
                  angle: swipeProgress > 0 ? -0.3 : 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),


            // Content
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${character.name}, ${character.age}',
                        style: const TextStyle(
                          fontSize: 32,
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
                  Text(
                    character.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    character.shortBio,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Personality traits
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: character.traits.take(3).map((trait) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          trait.name[0].toUpperCase() + trait.name.substring(1),
                          style: const TextStyle(
                            fontSize: 13,
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

/// Action button
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
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

/// Match overlay
class _MatchOverlay extends ConsumerWidget {
  final CharacterEntity character;
  final VoidCallback onDismiss;
  final int matchCount;

  const _MatchOverlay({
    required this.character,
    required this.onDismiss,
    required this.matchCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing hearts effect
            Text(
              '💕',
              style: const TextStyle(fontSize: 60),
            ).animate(onPlay: (c) => c.repeat())
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
                .then()
                .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
            const SizedBox(height: 16),

            Text(
              "It's a Match!",
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
              curve: Curves.elasticOut,
              duration: 600.ms,
            ),
            const SizedBox(height: 8),

            Text(
              'You and ${character.name} liked each other!',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),

            // Avatar row - user and character
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User avatar placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
                ).animate().fadeIn(delay: 300.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                ),
                const SizedBox(width: 20),
                // Heart icon
                Text(
                  '❤️',
                  style: const TextStyle(fontSize: 30),
                ).animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3))
                    .then()
                    .scale(begin: const Offset(1.3, 1.3), end: const Offset(1, 1)),
                const SizedBox(width: 20),
                // Character avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: character.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surface,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
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

            // Let's Start Chatting button
            ElevatedButton(
              onPressed: () async {
                // Complete onboarding
                await setOnboardingCompleted();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Hadi Başlayalım! 💬',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
            const SizedBox(height: 16),

            // Tap to dismiss
            TextButton(
              onPressed: onDismiss,
              child: Text(
                'Daha fazla swipe etmek istiyorum',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
