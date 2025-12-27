import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/media_entity.dart';
import '../providers/media_providers.dart';

/// Model selector widget
class ModelSelector extends ConsumerWidget {
  final bool enabled;

  const ModelSelector({
    super.key,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(availableModelsProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Model',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        modelsAsync.when(
          data: (models) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: models.map((model) {
              final isSelected = model.id == selectedModel;
              return _ModelChip(
                model: model,
                isSelected: isSelected,
                enabled: enabled,
                onTap: () {
                  ref.read(selectedModelProvider.notifier).state = model.id;
                },
              );
            }).toList(),
          ),
          loading: () => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => Text(
            'Failed to load models',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

class _ModelChip extends StatelessWidget {
  final AIModel model;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModelChip({
    required this.model,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : (isDark ? AppColors.surfaceDark : AppColors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
                    : AppColors.textTertiary.withValues(alpha: 0.2)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed indicator
            _SpeedBadge(speed: model.speed),
            const SizedBox(width: 8),
            
            // Model info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                  ),
                ),
                Text(
                  model.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            
            // Selection indicator
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  final String speed;

  const _SpeedBadge({required this.speed});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (speed.toLowerCase()) {
      case 'fast':
        color = AppColors.success;
        icon = Icons.bolt;
        break;
      case 'slow':
        color = AppColors.warning;
        icon = Icons.hourglass_bottom;
        break;
      default:
        color = AppColors.info;
        icon = Icons.speed;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}



