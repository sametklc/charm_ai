import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/screens/main_wrapper.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/data/repositories/predefined_characters.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';

/// Chat History Screen - WhatsApp style conversation list
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        actions: [
          IconButton(
            onPressed: () => _confirmDeleteAllChats(context, ref),
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: AppColors.error.withOpacity(0.8),
            ),
            tooltip: 'Clear All Chats',
          ),
          IconButton(
            onPressed: () {
              // Search functionality - future feature
            },
            icon: Icon(
              Icons.search,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return _buildEmptyState(context, ref, isDark);
          }
          return _buildConversationList(context, ref, conversations, isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error, isDark),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 60,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'No Matches Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Text(
              'Start swiping in Discover to find\nyour perfect companion!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to Discover tab
                ref.read(bottomNavIndexProvider.notifier).state = 0;
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Go to Discover'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    WidgetRef ref,
    List<ConversationEntity> conversations,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        
        // Try to get character from predefined list first
        var character = PredefinedCharacters.getById(conversation.characterId);
        
        // If not found, it might be a custom character
        if (character == null) {
          // Use characterName and characterAvatar from conversation if available
          var characterName = conversation.characterName;
          var characterAvatar = conversation.characterAvatar;
          
          // If characterName is null/empty, try to load from Firestore (async, will be handled in _ChatTile)
          // For now, create a placeholder - will be loaded on tap or in FutureBuilder
          character = CharacterEntity(
            id: conversation.characterId,
            name: characterName?.isNotEmpty == true ? characterName! : 'Unknown',
            age: 25,
            shortBio: 'Your custom companion',
            personalityDescription: 'Custom AI companion',
            systemPrompt: 'You are a friendly AI companion.',
            avatarUrl: Helpers.fixImageUrl(characterAvatar),
            voiceStyle: VoiceStyle.soft,
            traits: [],
            interests: [],
            nationality: 'Unknown',
            occupation: 'Companion',
          );
        }
        
        return _ChatTile(
          conversation: conversation,
          character: character,
          onTap: () => _openChat(context, ref, conversation, character),
          onLongPress: () => _showOptionsSheet(context, ref, conversation),
        ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        );
      },
    );
  }

  Future<void> _openChat(
    BuildContext context,
    WidgetRef ref,
    ConversationEntity conversation,
    CharacterEntity? character,
  ) async {
    print('🔵 Chats: ========== _openChat START ==========');
    print('🔵 Chats: conversation.id: ${conversation.id}');
    print('🔵 Chats: conversation.characterId: ${conversation.characterId}');
    print('🔵 Chats: conversation.characterName: "${conversation.characterName}"');
    print('🔵 Chats: conversation.characterAvatar: "${conversation.characterAvatar != null && conversation.characterAvatar!.length > 50 ? "${conversation.characterAvatar!.substring(0, 50)}..." : conversation.characterAvatar}"');
    print('🔵 Chats: character parameter: ${character?.name ?? "null"} (${character?.id ?? "null"})');
    
    if (character == null) {
      print('❌ Chats: Character is null, cannot open chat');
      print('🔵 Chats: ========== _openChat END (FAILED) ==========');
      return;
    }
    
    print('✅ Chats: Character found: ${character.name} (${character.id})');
    print('🔵 Chats: Character avatarUrl: "${character.avatarUrl.length > 50 ? "${character.avatarUrl.substring(0, 50)}..." : character.avatarUrl}"');
    
    // CRITICAL FIX: If character.avatarUrl is empty but conversation has characterAvatar, use it!
    // This happens for preset characters that aren't in Firestore
    String effectiveAvatarUrl = character.avatarUrl;
    if (effectiveAvatarUrl.isEmpty && conversation.characterAvatar != null && conversation.characterAvatar!.isNotEmpty) {
      effectiveAvatarUrl = conversation.characterAvatar!;
      print('🔵 Chats: Using conversation.characterAvatar instead of empty character.avatarUrl');
    }
    
    // Fix avatarUrl (ensure https:// prefix)
    if (effectiveAvatarUrl.isNotEmpty) {
      final fixedAvatarUrl = Helpers.fixImageUrl(effectiveAvatarUrl);
      if (fixedAvatarUrl != character.avatarUrl) {
        print('🔵 Chats: Fixing avatarUrl - adding https:// prefix or using conversation avatar');
        character = CharacterEntity(
          id: character.id,
          name: character.name,
          age: character.age,
          shortBio: character.shortBio,
          personalityDescription: character.personalityDescription,
          systemPrompt: character.systemPrompt,
          avatarUrl: fixedAvatarUrl,
          coverImageUrl: character.coverImageUrl != null ? Helpers.fixImageUrl(character.coverImageUrl) : null,
          voiceStyle: character.voiceStyle,
          traits: character.traits,
          interests: character.interests,
          nationality: character.nationality,
          occupation: character.occupation,
          isPremium: character.isPremium,
          isActive: character.isActive,
          physicalDescription: character.physicalDescription,
        );
        print('✅ Chats: Character avatarUrl fixed: "${character.avatarUrl.length > 50 ? "${character.avatarUrl.substring(0, 50)}..." : character.avatarUrl}"');
      }
    }
    
    // Reset chat controller state before opening a new chat
    print('🔵 Chats: Resetting chat controller state...');
    ref.read(chatControllerProvider.notifier).resetConversation();
    print('✅ Chats: ChatController state reset.');
    
    // If character is a placeholder (missing avatar), try to load from Firestore
    if (character.avatarUrl.isEmpty || character.id.startsWith('custom_')) {
      print('🔵 Chats: Character is placeholder or custom, loading from Firestore...');
      try {
        final firestore = ref.read(firestoreProvider);
        print('🔵 Chats: Fetching character from Firestore: ${character.id}');
        final characterDoc = await firestore.collection('characters').doc(character.id).get();
        
        if (characterDoc.exists) {
          print('✅ Chats: Character document found in Firestore');
          final data = characterDoc.data() as Map<String, dynamic>;
          print('🔵 Chats: Character data keys: ${data.keys.join(", ")}');
          print('🔵 Chats: Character name from Firestore: ${data['name']}');
          final avatarUrlStr = data['avatarUrl']?.toString() ?? '';
          print('🔵 Chats: Character avatarUrl from Firestore: "${avatarUrlStr.length > 50 ? "${avatarUrlStr.substring(0, 50)}..." : avatarUrlStr}"');
          character = CharacterEntity(
            id: data['id'] ?? character.id,
            name: data['name'] ?? character.name,
            age: data['age'] ?? character.age,
            shortBio: data['shortBio'] ?? character.shortBio,
            personalityDescription: data['personalityDescription'] ?? character.personalityDescription,
            systemPrompt: data['systemPrompt'] ?? character.systemPrompt,
            avatarUrl: Helpers.fixImageUrl(data['avatarUrl']?.toString() ?? character.avatarUrl),
            coverImageUrl: data['coverImageUrl'],
            voiceStyle: VoiceStyle.values.firstWhere(
              (v) => v.name == (data['voiceStyle'] ?? 'soft'),
              orElse: () => VoiceStyle.soft,
            ),
            traits: (data['traits'] as List<dynamic>?)?.map((t) => PersonalityTrait.values.firstWhere(
              (v) => v.name == t,
              orElse: () => PersonalityTrait.caring,
            )).toList() ?? character.traits,
            interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? character.interests,
            nationality: data['nationality'] ?? character.nationality,
            occupation: data['occupation'] ?? character.occupation,
            isPremium: data['isPremium'] ?? false,
            isActive: data['isActive'] ?? true,
            physicalDescription: data['physicalDescription'],
          );
          print('✅ Chats: Character loaded from Firestore: ${character.name}');
        } else {
          print('⚠️ Chats: Character document not found in Firestore, using placeholder');
        }
      } catch (e, stackTrace) {
        print('❌ Chats: Error loading custom character: $e');
        print('Stack trace: $stackTrace');
        // Continue with placeholder character
      }
    }
    
    // Final null check before navigation
    if (character == null) {
      print('❌ Chats: Character is null after loading, cannot navigate');
      return;
    }
    
    if (context.mounted) {
      print('🔵 Chats: Navigating to chat screen with character: ${character.name} (${character.id})');
      print('🔵 Chats: Character avatarUrl: "${character.avatarUrl.length > 50 ? "${character.avatarUrl.substring(0, 50)}..." : character.avatarUrl}"');
      print('🔵 Chats: CRITICAL - Passing conversationId: ${conversation.id}');
      
      // CRITICAL FIX: Pass both character AND conversationId
      // This ensures we load the correct conversation's messages
      Navigator.pushNamed(
        context, 
        '/chat', 
        arguments: {
          'character': character,
          'conversationId': conversation.id,
        },
      );
      print('✅ Chats: Navigation to chat completed');
    } else {
      print('❌ Chats: Context not mounted, cannot navigate');
    }
    print('🔵 Chats: ========== _openChat END ==========');
  }

  void _showOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    ConversationEntity conversation,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get character - try predefined first, then create placeholder for custom
    var character = PredefinedCharacters.getById(conversation.characterId);
    
    // If not found, it might be a custom character
    if (character == null) {
      var characterName = conversation.characterName;
      var characterAvatar = conversation.characterAvatar;
      
      // Try to load from Firestore if it's a custom character
      if (conversation.characterId.startsWith('custom_')) {
        try {
          final firestore = ref.read(firestoreProvider);
          final characterDoc = await firestore
              .collection('characters')
              .doc(conversation.characterId)
              .get();
          
          if (characterDoc.exists) {
            final data = characterDoc.data() as Map<String, dynamic>;
            character = CharacterEntity(
              id: data['id'] ?? conversation.characterId,
              name: data['name'] ?? characterName ?? 'Unknown',
              age: data['age'] ?? 25,
              shortBio: data['shortBio'] ?? 'Your custom companion',
              personalityDescription: data['personalityDescription'] ?? 'Custom AI companion',
              systemPrompt: data['systemPrompt'] ?? 'You are a friendly AI companion.',
              avatarUrl: Helpers.fixImageUrl(data['avatarUrl']?.toString() ?? characterAvatar ?? ''),
              voiceStyle: VoiceStyle.values.firstWhere(
                (v) => v.name == (data['voiceStyle'] ?? 'soft'),
                orElse: () => VoiceStyle.soft,
              ),
              traits: (data['traits'] as List<dynamic>?)?.map((t) => PersonalityTrait.values.firstWhere(
                (v) => v.name == t,
                orElse: () => PersonalityTrait.caring,
              )).toList() ?? [],
              interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? [],
              nationality: data['nationality'] ?? 'Unknown',
              occupation: data['occupation'] ?? 'Companion',
            );
          }
        } catch (e) {
          print('❌ ChatHistoryScreen: Error loading custom character: $e');
        }
      }
      
      // If still null, create placeholder
      if (character == null) {
        character = CharacterEntity(
          id: conversation.characterId,
          name: characterName?.isNotEmpty == true ? characterName! : 'Unknown',
          age: 25,
          shortBio: 'Your custom companion',
          personalityDescription: 'Custom AI companion',
          systemPrompt: 'You are a friendly AI companion.',
          avatarUrl: Helpers.fixImageUrl(characterAvatar ?? ''),
          voiceStyle: VoiceStyle.soft,
          traits: [],
          interests: [],
          nationality: 'Unknown',
          occupation: 'Companion',
        );
      }
    }

    if (!context.mounted) return;
    
    // At this point, character should never be null, but add safety check
    if (character == null) {
      print('❌ ChatHistoryScreen: Character is null, cannot show options');
      return;
    }
    
    // Store in non-nullable variable for type safety
    final nonNullCharacter = character;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('View ${nonNullCharacter.name}\'s Profile'),
              onTap: () {
                Navigator.pop(context);
                _showCharacterProfile(context, nonNullCharacter);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                'Delete Chat',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteChat(context, ref, conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChat(
    BuildContext context,
    WidgetRef ref,
    ConversationEntity conversation,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: const Text('Delete Chat?'),
        content: const Text(
          'This will permanently delete all messages in this conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading indicator
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting chat...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              
              try {
                print('🔵 ChatHistoryScreen: Starting delete conversation: ${conversation.id}');
                final deleteConversation = ref.read(deleteConversationUseCaseProvider);
                final result = await deleteConversation(conversation.id);
                
                result.fold(
                  (failure) {
                    print('❌ ChatHistoryScreen: Failed to delete conversation: ${failure.message}');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${failure.message}'),
                          backgroundColor: AppColors.error,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  (_) {
                    print('✅ ChatHistoryScreen: Conversation deleted successfully');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chat deleted successfully'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    // Stream will automatically update
                  },
                );
              } catch (e, stackTrace) {
                print('❌ ChatHistoryScreen: Exception deleting conversation: $e');
                print('Stack trace: $stackTrace');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showCharacterProfile(BuildContext context, CharacterEntity character) {
    if (character == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: character.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: Helpers.fixImageUrl(character.avatarUrl),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.primary.withOpacity(0.2),
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: const Icon(Icons.person, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name and Age
                    Text(
                      '${character.name}, ${character.age}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (character.subtitle.isNotEmpty)
                      Text(
                        character.subtitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (character.shortBio.isNotEmpty)
                      Text(
                        character.shortBio,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Personality Description
                    if (character.personalityDescription.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? AppColors.surfaceVariantDark 
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About Me',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              character.personalityDescription.trim(),
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Interests
                    if (character.interests.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Interests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: character.interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAllChats(
    BuildContext context,
    WidgetRef ref,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.read(currentUserProvider);
    
    if (user == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: const Text('Clear All Chats?'),
        content: const Text(
          'This will permanently delete ALL your conversations and messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading indicator
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Clearing all chats...'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
              
              try {
                print('🔵 ChatHistoryScreen: Starting delete all conversations for user: ${user.uid}');
                final deleteAllConversations = ref.read(deleteAllConversationsUseCaseProvider);
                final result = await deleteAllConversations(user.uid);
                
                result.fold(
                  (failure) {
                    print('❌ ChatHistoryScreen: Failed to delete all conversations: ${failure.message}');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${failure.message}'),
                          backgroundColor: AppColors.error,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  (_) {
                    print('✅ ChatHistoryScreen: All conversations deleted successfully');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All chats cleared successfully'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              } catch (e, stackTrace) {
                print('❌ ChatHistoryScreen: Exception deleting all conversations: $e');
                print('Stack trace: $stackTrace');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat tile widget - Individual conversation item
class _ChatTile extends StatelessWidget {
  final ConversationEntity conversation;
  final CharacterEntity? character;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatTile({
    required this.conversation,
    required this.character,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Builder(
                      builder: (context) {
                        // Priority: conversation.characterAvatar > character.avatarUrl > ''
                        final rawAvatarUrl = (conversation.characterAvatar != null && conversation.characterAvatar!.isNotEmpty)
                            ? conversation.characterAvatar!
                            : (character?.avatarUrl.isNotEmpty == true 
                                ? character!.avatarUrl 
                                : '');
                        
                        // Fix URL by adding https:// prefix if missing
                        final avatarUrl = Helpers.fixImageUrl(rawAvatarUrl);
                        
                        return avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.primary.withOpacity(0.2),
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.primary.withOpacity(0.2),
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                              )
                            : Container(
                                color: AppColors.primary.withOpacity(0.2),
                                child: const Icon(Icons.person, color: Colors.white),
                              );
                      },
                    ),
                  ),
                ),
                // Online indicator
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          // Priority: conversation.characterName > character.name > 'Unknown'
                          (conversation.characterName != null && conversation.characterName!.isNotEmpty)
                              ? conversation.characterName!
                              : (character?.name ?? 'Unknown'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: conversation.unreadCount > 0 
                                ? FontWeight.bold 
                                : FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(conversation.displayTimestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: conversation.unreadCount > 0
                              ? AppColors.primary
                              : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
                          fontWeight: conversation.unreadCount > 0 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message and unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayLastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: conversation.unreadCount > 0
                                ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                            fontWeight: conversation.unreadCount > 0 
                                ? FontWeight.w500 
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      // Today - show time
      return Helpers.formatMessageTime(timestamp);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    } else {
      // Older - show date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

