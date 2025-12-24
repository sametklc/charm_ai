import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../providers/chat_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/image_bubble.dart';

/// Main Chat Screen - WhatsApp/Telegram Style
class ChatScreen extends ConsumerStatefulWidget {
  final CharacterEntity? character;

  const ChatScreen({super.key, this.character});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final character = widget.character;
      if (character != null) {
        ref.read(chatControllerProvider.notifier).setCharacter(character);
      }
      final chatState = ref.read(chatControllerProvider);
      if (chatState.conversationId == null) {
        await ref.read(chatControllerProvider.notifier).initConversation(
          user.uid,
          character: character,
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend(String message) {
    ref.read(chatControllerProvider.notifier).sendMessage(message);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _handleSelfieRequest() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      ref.read(chatControllerProvider.notifier).requestSelfie(user.uid);
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _goBack() {
    Navigator.pushReplacementNamed(context, '/characters');
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final character = widget.character ?? chatState.currentCharacter;

    // Auto-scroll when messages change
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.currentStreamingContent != next.currentStreamingContent) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      backgroundColor: isDark 
          ? AppColors.backgroundDark 
          : const Color(0xFFECE5DD), // WhatsApp-like background
      appBar: _buildAppBar(character, isDark),
      body: Container(
        // Chat wallpaper pattern
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.backgroundDark 
              : const Color(0xFFECE5DD),
        ),
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: chatState.messages.isEmpty && !chatState.isLoading
                  ? _buildEmptyState(character, isDark)
                  : _buildMessageList(chatState, isDark),
            ),

            // Input field with camera button
            ChatInput(
              onSend: _handleSend,
              onRequestSelfie: _handleSelfieRequest,
              isLoading: chatState.isLoading || chatState.isStreaming,
              isSelfieLoading: chatState.isSelfieLoading,
              enabled: chatState.conversationId != null,
              hintText: character != null 
                  ? 'Message ${character.name}...' 
                  : 'Type a message...',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CharacterEntity? character, bool isDark) {
    return AppBar(
      elevation: 1,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      leading: IconButton(
        onPressed: _goBack,
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: () => _showCharacterProfile(character),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // Character Avatar
              Hero(
                tag: 'character_avatar_${character?.id}',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: character?.avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: character!.avatarUrl,
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
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character?.name ?? 'Charm AI',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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
      ),
      actions: [
        // Video call (placeholder)
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video call coming soon!')),
            );
          },
          icon: Icon(
            Icons.videocam_rounded,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        // More options
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                _showCharacterProfile(character);
                break;
              case 'clear':
                ref.read(chatControllerProvider.notifier).clearChat();
                break;
              case 'change':
                _goBack();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 12),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Clear Chat'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'change',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 20),
                  SizedBox(width: 12),
                  Text('Change Partner'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCharacterProfile(CharacterEntity? character) {
    if (character == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CharacterProfileSheet(character: character),
    );
  }

  Widget _buildEmptyState(CharacterEntity? character, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Character Avatar
            if (character != null)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: character.avatarUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut)
            else
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 45,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            
            Text(
              character != null 
                  ? 'Say hi to ${character.name}! 👋'
                  : 'Start a Conversation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            
            Text(
              character != null 
                  ? character.shortBio
                  : 'Send your first message to begin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),

            // Quick conversation starters
            if (character != null) ...[
              Text(
                'Conversation Starters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _getConversationStarters(character).map((starter) {
                  return _QuickPromptChip(
                    label: starter,
                    onTap: () => _handleSend(starter),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _getConversationStarters(CharacterEntity character) {
    // Personalized starters based on character traits/interests
    final starters = <String>[];
    
    if (character.traits.contains(PersonalityTrait.artistic)) {
      starters.add('What inspires your art? 🎨');
    }
    if (character.traits.contains(PersonalityTrait.sporty)) {
      starters.add('What\'s your favorite workout? 💪');
    }
    if (character.traits.contains(PersonalityTrait.nerdy)) {
      starters.add('What games are you playing? 🎮');
    }
    if (character.traits.contains(PersonalityTrait.romantic)) {
      starters.add('What\'s your idea of a perfect date? 💕');
    }
    if (character.traits.contains(PersonalityTrait.intellectual)) {
      starters.add('What book are you reading? 📚');
    }
    
    // Always add these generic ones
    starters.addAll([
      'Hey ${character.name}! How are you? 😊',
      'Tell me about yourself!',
    ]);
    
    return starters.take(4).toList();
  }

  Widget _buildMessageList(ChatState chatState, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: chatState.messages.length +
          (chatState.isLoading ? 1 : 0) +
          (chatState.isStreaming && chatState.currentStreamingContent.isNotEmpty ? 1 : 0) +
          (chatState.isSelfieLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading bubble
        if (chatState.isLoading && index == chatState.messages.length) {
          return const LoadingBubble();
        }

        // Show streaming bubble
        if (chatState.isStreaming &&
            chatState.currentStreamingContent.isNotEmpty &&
            index == chatState.messages.length) {
          return StreamingBubble(content: chatState.currentStreamingContent);
        }
        
        // Show selfie loading bubble
        if (chatState.isSelfieLoading && 
            index == chatState.messages.length) {
          return const SelfieLoadingBubble();
        }

        // Show regular message
        final message = chatState.messages[index];
        
        // If it's an image message, show ImageBubble
        if (message.isImage) {
          return ImageBubble(
            message: message,
            showTimestamp: _shouldShowTimestamp(chatState.messages, index),
          );
        }
        
        // If it's a selfie loading message, show loading bubble
        if (message.isSelfieLoading) {
          return const SelfieLoadingBubble();
        }
        
        // Regular text message
        return ChatBubble(
          message: message,
          showTimestamp: _shouldShowTimestamp(chatState.messages, index),
          characterAvatar: chatState.currentCharacter?.avatarUrl,
        );
      },
    );
  }

  bool _shouldShowTimestamp(List messages, int index) {
    if (index == messages.length - 1) return true;

    final current = messages[index];
    final next = messages[index + 1];

    // Show timestamp if next message is from different role
    if (current.role != next.role) return true;

    // Show timestamp if more than 5 minutes apart
    final diff = next.timestamp.difference(current.timestamp);
    return diff.inMinutes > 5;
  }
}

/// Quick prompt chip widget
class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickPromptChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.surfaceDark 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Character Profile Bottom Sheet
class _CharacterProfileSheet extends StatelessWidget {
  final CharacterEntity character;

  const _CharacterProfileSheet({required this.character});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
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
                      child: CachedNetworkImage(
                        imageUrl: character.avatarUrl,
                        fit: BoxFit.cover,
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
                  Text(
                    character.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
    );
  }
}
