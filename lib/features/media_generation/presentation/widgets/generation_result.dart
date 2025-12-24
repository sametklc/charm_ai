import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/media_entity.dart';

/// Widget to display generated image result
class GenerationResult extends StatelessWidget {
  final GeneratedMediaEntity media;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onRegenerate;

  const GenerationResult({
    super.key,
    required this.media,
    this.onDownload,
    this.onShare,
    this.onFavorite,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image display
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: media.width / media.height,
            child: CachedNetworkImage(
              imageUrl: media.firstImageUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: media.isFavorite ? Icons.favorite : Icons.favorite_border,
              label: 'Favorite',
              color: media.isFavorite ? AppColors.error : null,
              onTap: onFavorite,
            ),
            _ActionButton(
              icon: Icons.download,
              label: 'Download',
              onTap: onDownload,
            ),
            _ActionButton(
              icon: Icons.share,
              label: 'Share',
              onTap: onShare,
            ),
            _ActionButton(
              icon: Icons.refresh,
              label: 'Regenerate',
              onTap: onRegenerate,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Generation info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generation Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Model', value: media.model),
              _InfoRow(label: 'Size', value: '${media.width} x ${media.height}'),
              _InfoRow(label: 'Time', value: '${media.generationTime.toStringAsFixed(1)}s'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: buttonColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

