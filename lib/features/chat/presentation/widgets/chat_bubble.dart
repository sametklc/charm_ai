import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../domain/entities/message_entity.dart';

/// Chat message bubble widget - WhatsApp style
class ChatBubble extends StatelessWidget {
  final MessageEntity message;
  final bool showTimestamp;
  final String? characterAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.characterAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message bubble
          GestureDetector(
            onLongPress: () => _copyToClipboard(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isError
                    ? AppColors.error.withOpacity(0.1)
                    : isUser
                        ? AppColors.primary
                        : (isDark ? AppColors.aiBubbleDark : AppColors.aiBubble),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error icon if error message
                  if (message.isError) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Message content
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: message.isError
                          ? AppColors.error
                          : isUser
                              ? Colors.white
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Timestamp
          if (showTimestamp) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                Helpers.formatMessageTime(message.timestamp),
                style: TextStyle(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Streaming message bubble (shows typing animation)
class StreamingBubble extends StatelessWidget {
  final String content;

  const StreamingBubble({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 48, bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.aiBubbleDark : AppColors.aiBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                content.isEmpty ? '' : content,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const _TypingIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Typing indicator animation
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final opacity = (value < 0.5 ? value : 1.0 - value) * 2;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3 + (opacity * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Loading bubble (shows while waiting for response)
class LoadingBubble extends StatelessWidget {
  const LoadingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 48, bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.aiBubbleDark : AppColors.aiBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: const _TypingIndicator(),
      ),
    );
  }
}
