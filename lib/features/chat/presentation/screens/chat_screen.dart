import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/chat_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

/// Main Chat Screen
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize conversation when screen loads
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
      final chatState = ref.read(chatControllerProvider);
      if (chatState.conversationId == null) {
        await ref.read(chatControllerProvider.notifier).initConversation(user.uid);
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
    // Scroll after a short delay to ensure new message is rendered
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _startNewChat() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      ref.read(chatControllerProvider.notifier).startNewChat(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-scroll when messages change
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.currentStreamingContent != next.currentStreamingContent) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Charm AI'),
          ],
        ),
        actions: [
          // New chat button
          IconButton(
            onPressed: _startNewChat,
            tooltip: 'New Chat',
            icon: const Icon(Icons.add_comment_outlined),
          ),
          // Menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  ref.read(chatControllerProvider.notifier).clearChat();
                  break;
              }
            },
            itemBuilder: (context) => [
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
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.messages.isEmpty && !chatState.isLoading
                ? _buildEmptyState(isDark)
                : _buildMessageList(chatState, isDark),
          ),

          // Input field
          ChatInput(
            onSend: _handleSend,
            isLoading: chatState.isLoading || chatState.isStreaming,
            enabled: chatState.conversationId != null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
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
            ),
            const SizedBox(height: 32),
            Text(
              'Start a Conversation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me anything! I\'m powered by GPT-4o Mini\nand ready to help.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Quick prompts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _QuickPromptChip(
                  label: 'Explain AI to me',
                  onTap: () => _handleSend('Explain artificial intelligence to me in simple terms'),
                ),
                _QuickPromptChip(
                  label: 'Write a poem',
                  onTap: () => _handleSend('Write me a short, beautiful poem about nature'),
                ),
                _QuickPromptChip(
                  label: 'Help me code',
                  onTap: () => _handleSend('I need help with coding. What languages do you know?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: chatState.messages.length +
          (chatState.isLoading ? 1 : 0) +
          (chatState.isStreaming && chatState.currentStreamingContent.isNotEmpty ? 1 : 0),
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

        // Show regular message
        final message = chatState.messages[index];
        return ChatBubble(
          message: message,
          showTimestamp: _shouldShowTimestamp(chatState.messages, index),
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
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
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

