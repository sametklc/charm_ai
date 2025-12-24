import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Prompt input widget for media generation
class PromptInput extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController? negativeController;
  final bool enabled;
  final bool showNegativePrompt;
  final VoidCallback? onToggleNegative;

  const PromptInput({
    super.key,
    required this.controller,
    this.negativeController,
    this.enabled = true,
    this.showNegativePrompt = false,
    this.onToggleNegative,
  });

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main prompt input
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
                  : AppColors.textTertiary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe what you want to create...\n\nE.g., "A serene mountain landscape at sunset with golden clouds"',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                    height: 1.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              
              // Bottom actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.textTertiaryDark.withValues(alpha: 0.1)
                          : AppColors.textTertiary.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Character count
                    Text(
                      '${widget.controller.text.length}/2000',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    
                    // Toggle negative prompt
                    if (widget.onToggleNegative != null)
                      TextButton.icon(
                        onPressed: widget.enabled ? widget.onToggleNegative : null,
                        icon: Icon(
                          widget.showNegativePrompt
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          size: 18,
                        ),
                        label: Text(
                          widget.showNegativePrompt ? 'Hide negative' : 'Add negative',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Negative prompt input
        if (widget.showNegativePrompt && widget.negativeController != null) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: TextField(
              controller: widget.negativeController,
              enabled: widget.enabled,
              maxLines: 2,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'What to avoid (e.g., "blurry, low quality, distorted")',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                prefixIcon: Icon(
                  Icons.block,
                  color: AppColors.error.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

