import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/navigation_provider.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_input.dart';
import '../widgets/image_bubble.dart';
import '../widgets/message_bubble.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Chat Screen - Main chat interface
class ChatScreen extends ConsumerStatefulWidget {
  final CharacterEntity? character;
  final String? conversationId;

  const ChatScreen({
    super.key,
    this.character,
    this.conversationId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isKeyboardVisible = false;
  bool _isAutoScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
      _checkKeyboardVisibility();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    print('🔵 ChatScreen: ========== _initChat START ==========');
    final user = ref.read(currentUserProvider);
    if (user == null) {
      print('❌ ChatScreen: User is null, cannot initialize chat');
      return;
    }

    final character = widget.character;
    final widgetConversationId = widget.conversationId;

    print('🔵 ChatScreen: user=${user.uid}, character=${character?.name}, conversationId=$widgetConversationId');
    print('🔵 ChatScreen: widget.character: ${widget.character?.name ?? "null"}');
    print('🔵 ChatScreen: widget.conversationId: ${widget.conversationId ?? "null"}');

    // Case 1: Coming from ChatHistoryScreen with a conversationId
    if (widgetConversationId != null && widgetConversationId.isNotEmpty) {
      print('🔵 ChatScreen: Loading existing conversation: $widgetConversationId');
      await ref.read(chatControllerProvider.notifier).loadConversationById(
        widgetConversationId,
        character,
      );
      print('✅ ChatScreen: Conversation loaded');
      return;
    }

    // Case 2: Coming from Discover/Create with a character (no conversationId)
    if (character != null) {
      print('🔵 ChatScreen: Initializing conversation for character: ${character.name}');
      await ref.read(chatControllerProvider.notifier).initConversation(
        user.uid,
        character: character,
      );
      print('✅ ChatScreen: Conversation initialized');
      return;
    }

    print('⚠️ ChatScreen: No character or conversationId provided');
  }

  void _checkKeyboardVisibility() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.of(context);
    final newKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    if (newKeyboardVisible != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newKeyboardVisible;
      });

      if (newKeyboardVisible) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    }
  }

  void _onScroll() {
    // Don't close keyboard during auto-scroll
    if (_isAutoScrolling) return;

    // Close keyboard when user scrolls up while keyboard is visible
    if (_isKeyboardVisible && _scrollController.hasClients) {
      final position = _scrollController.position;
      // Only close if user is significantly away from bottom (more than 150px)
      // This prevents closing during auto-scroll to bottom
      if (position.pixels < position.maxScrollExtent - 150) {
        _focusNode.unfocus();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _isAutoScrolling = true;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ).then((_) {
        // Reset flag after animation completes
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isAutoScrolling = false;
            });
          }
        });
      });
    }
  }

  void _handleSend(String message) {
    print('🔵 ChatScreen: _handleSend called with message: "${message.substring(0, message.length > 50 ? 50 : message.length)}${message.length > 50 ? "..." : ""}"');
    final chatState = ref.read(chatControllerProvider);
    print('🔵 ChatScreen: Current conversationId: ${chatState.conversationId}');
    print('🔵 ChatScreen: Current character: ${chatState.currentCharacter?.name ?? "null"}');

    if (chatState.conversationId == null) {
      print('❌ ChatScreen: Cannot send message - conversationId is null');
      return;
    }

    ref.read(chatControllerProvider.notifier).sendMessage(message);
    print('✅ ChatScreen: Message sent to controller');
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _handleSelfieRequest() {
    // Camera button now prefills text input instead of immediately generating
    // This is handled by ChatInput widget's _handleSelfieRequest
  }

  void _goBack() {
    // Go back to Chats tab in MainWrapper
    ref.read(bottomNavIndexProvider.notifier).state = 1; // Chats tab
  }

  Future<void> _showClearMessagesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Messages'),
        content: const Text('Are you sure you want to clear all messages in this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _clearAllMessages();
    }
  }

  Future<void> _clearAllMessages() async {
    final chatState = ref.read(chatControllerProvider);
    if (chatState.conversationId == null) return;

    try {
      final firestore = ref.read(firestoreProvider);

      // Delete all messages in this conversation
      final messagesQuery = await firestore
          .collection('conversations')
          .doc(chatState.conversationId!)
          .collection('messages')
          .get();

      final batch = firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update conversation lastMessage and lastMessageTimestamp to null
      batch.update(
        firestore.collection('conversations').doc(chatState.conversationId!),
        {
          'lastMessage': null,
          'lastMessageTimestamp': null,
        },
      );

      await batch.commit();

      // Clear local state
      ref.read(chatControllerProvider.notifier).clearMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear messages: $e')),
        );
      }
    }
  }

  void _showCharacterProfile(CharacterEntity? character) {
    if (character == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark
              : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Character avatar and name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary,
                      backgroundImage: character.avatarUrl != null
                          ? NetworkImage(character.avatarUrl!)
                          : null,
                      child: character.avatarUrl == null
                          ? Text(
                              character.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      character.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Online',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

          // Character description
          if (character.personalityDescription.isNotEmpty) ...[
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              character.personalityDescription,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],

              // Character traits
              if (character.traits.isNotEmpty) ...[
                const Text(
                  'Personality',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: character.traits.map((trait) {
                    return Chip(
                      label: Text(
                        trait.toString().split('.').last,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final character = widget.character ?? chatState.currentCharacter;

    // Check keyboard visibility on every build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKeyboardVisibility();
    });

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
          : const Color(0xFFECE5DD),
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(character, isDark),
      body: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.backgroundDark
              : const Color(0xFFECE5DD),
        ),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Only close keyboard when tapping on messages area (not during auto-scroll)
                onTap: () {
                  if (_isKeyboardVisible && !_isAutoScrolling) {
                    _focusNode.unfocus();
                  }
                },
                child: chatState.isLoading && chatState.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : chatState.messages.isEmpty
                        ? _buildEmptyState(character, isDark)
                        : _buildMessageList(chatState, isDark, user),
              ),
            ),
            ChatInput(
              onSend: _handleSend,
              onRequestSelfie: _handleSelfieRequest,
              isLoading: chatState.isLoading || chatState.isStreaming,
              isSelfieLoading: chatState.isSelfieLoading,
              enabled: chatState.conversationId != null,
              hintText: character != null
                  ? 'Message ${character.name}...'
                  : 'Type a message...',
              focusNode: _focusNode,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CharacterEntity? character, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
      title: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _showCharacterProfile(character),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              backgroundImage: character?.avatarUrl != null
                  ? NetworkImage(character!.avatarUrl!)
                  : null,
              child: character?.avatarUrl == null
                  ? Text(
                      character?.name.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: GestureDetector(
              onTap: () => _showCharacterProfile(character),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character?.name ?? 'Unknown Character',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final chatState = ref.watch(chatControllerProvider);
                      final status = chatState.isLoading || chatState.isStreaming
                          ? 'Typing...'
                          : 'Online';
                      final isOnline = status == 'Online';

                      return Text(
                        status,
                        style: TextStyle(
                          color: isOnline
                              ? Colors.green
                              : isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'clear_messages':
                _showClearMessagesDialog();
                break;
              case 'character_profile':
                _showCharacterProfile(character);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear_messages',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Clear Messages'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'character_profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Character Profile'),
                ],
              ),
            ),
          ],
          icon: Icon(
            Icons.more_vert,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(CharacterEntity? character, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Character avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: AppColors.primary,
            backgroundImage: character?.avatarUrl != null
                ? NetworkImage(character!.avatarUrl!)
                : null,
            child: character?.avatarUrl == null
                ? Text(
                    character?.name.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),

          // Welcome message
          Text(
            'Say hello to ${character?.name ?? "your character"}!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'Start a conversation and get to know them better.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Starter messages
          if (character != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // Conversation starters as bubbles/pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _getConversationStarters(character).map((starter) {
                          return InkWell(
                            onTap: () => _handleSend(starter),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                starter,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState, bool isDark, UserEntity? user) {
    print('🔵 ChatScreen: _buildMessageList called with ${chatState.messages.length} messages');
    for (int i = 0; i < chatState.messages.length; i++) {
      final msg = chatState.messages[i];
      print('  Message $i: ${msg.role.name} - "${msg.content.substring(0, min(30, msg.content.length))}${msg.content.length > 30 ? "..." : ""}"');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        final isLastMessage = index == chatState.messages.length - 1;
        final character = widget.character ?? chatState.currentCharacter;

        // Handle selfie loading messages
        if (message.isSelfieLoading) {
          return const SelfieLoadingBubble();
        }

        // Handle image messages
        if (message.isImage) {
          return ImageBubble(message: message);
        }

        // Add streaming content for the last AI message
        if (isLastMessage &&
            message.isAssistant &&
            chatState.isStreaming &&
            chatState.currentStreamingContent != null) {
          return Column(
            children: [
              MessageBubble(message: message, character: character, userAvatar: user?.photoUrl),
              if (chatState.currentStreamingContent!.isNotEmpty)
                MessageBubble(
                  message: message.copyWith(
                    content: chatState.currentStreamingContent!,
                  ),
                  character: character,
                  userAvatar: user?.photoUrl,
                ),
            ],
          );
        }

        return MessageBubble(message: message, character: character, userAvatar: user?.photoUrl);
      },
    );
  }

  List<String> _getConversationStarters(CharacterEntity character) {
    // Personalized starters based on character traits/interests
    final starters = <String>[];

    if (character.traits.contains('artistic')) {
      starters.addAll([
        'What inspires you?',
        'Tell me about your art',
        'What do you create?',
      ]);
    }

    if (character.traits.contains('adventurous')) {
      starters.addAll([
        'What\'s your favorite adventure?',
        'Tell me about your travels',
        'What excites you?',
      ]);
    }

    if (character.traits.contains('intellectual')) {
      starters.addAll([
        'What are you reading?',
        'What fascinates you?',
        'What\'s your perspective?',
      ]);
    }

    // Default starters if no specific traits
    if (starters.isEmpty) {
      starters.addAll([
        'Tell me about yourself',
        'What do you like to do?',
        'Send me a selfie! 📸',
      ]);
    }

    return starters.take(3).toList();
  }
}