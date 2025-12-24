import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/media_providers.dart';

/// Aspect ratio options
class AspectRatioOption {
  final String id;
  final String label;
  final int width;
  final int height;
  final IconData icon;

  const AspectRatioOption({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.icon,
  });
}

/// Available aspect ratios
const aspectRatios = [
  AspectRatioOption(id: '1:1', label: 'Square', width: 1024, height: 1024, icon: Icons.crop_square),
  AspectRatioOption(id: '16:9', label: 'Landscape', width: 1344, height: 768, icon: Icons.crop_landscape),
  AspectRatioOption(id: '9:16', label: 'Portrait', width: 768, height: 1344, icon: Icons.crop_portrait),
  AspectRatioOption(id: '4:3', label: '4:3', width: 1152, height: 896, icon: Icons.crop_din),
  AspectRatioOption(id: '3:4', label: '3:4', width: 896, height: 1152, icon: Icons.crop_din),
];

/// Aspect ratio selector widget
class AspectRatioSelector extends ConsumerWidget {
  final bool enabled;

  const AspectRatioSelector({
    super.key,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRatio = ref.watch(selectedAspectRatioProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aspect Ratio',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: aspectRatios.map((ratio) {
              final isSelected = ratio.id == selectedRatio;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _AspectRatioChip(
                  ratio: ratio,
                  isSelected: isSelected,
                  enabled: enabled,
                  onTap: () {
                    ref.read(selectedAspectRatioProvider.notifier).state = ratio.id;
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _AspectRatioChip extends StatelessWidget {
  final AspectRatioOption ratio;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _AspectRatioChip({
    required this.ratio,
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
            // Aspect ratio preview
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildAspectPreview(ratio.id, isSelected, isDark),
            ),
            const SizedBox(width: 8),
            Text(
              ratio.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspectPreview(String id, bool isSelected, bool isDark) {
    double widthFactor;
    double heightFactor;

    switch (id) {
      case '16:9':
        widthFactor = 1.0;
        heightFactor = 0.5;
        break;
      case '9:16':
        widthFactor = 0.5;
        heightFactor = 1.0;
        break;
      case '4:3':
        widthFactor = 1.0;
        heightFactor = 0.7;
        break;
      case '3:4':
        widthFactor = 0.7;
        heightFactor = 1.0;
        break;
      default:
        widthFactor = 1.0;
        heightFactor = 1.0;
    }

    return Center(
      child: Container(
        width: 16 * widthFactor,
        height: 16 * heightFactor,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.3)
              : (isDark
                  ? AppColors.textTertiaryDark.withValues(alpha: 0.3)
                  : AppColors.textTertiary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Get dimensions for aspect ratio
(int width, int height) getDimensionsForRatio(String ratioId) {
  final ratio = aspectRatios.firstWhere(
    (r) => r.id == ratioId,
    orElse: () => aspectRatios.first,
  );
  return (ratio.width, ratio.height);
}

