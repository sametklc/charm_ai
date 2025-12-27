import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../domain/entities/message_entity.dart';

/// Message Bubble Widget
class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final CharacterEntity? character;
  final String? userAvatar;
  final bool showAvatar;
  final bool showTimestamp;

  const MessageBubble({
    super.key,
    required this.message,
    this.character,
    this.userAvatar,
    this.showAvatar = true,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              backgroundImage: character?.avatarUrl != null
                  ? NetworkImage(character!.avatarUrl!)
                  : null,
              child: character?.avatarUrl == null
                  ? const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : isDark
                        ? AppColors.surfaceDark
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  if (showTimestamp && message.timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp!),
                      style: TextStyle(
                        color: isUser
                            ? Colors.white.withOpacity(0.7)
                            : isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser && showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: userAvatar != null
                  ? NetworkImage(userAvatar!)
                  : null,
              child: userAvatar == null
                  ? Text(
                      'U',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // This week - show day
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[timestamp.weekday - 1]} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Older - show date
      return '${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

