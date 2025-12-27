import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Divider with text in the middle (e.g., "OR")
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({
    super.key,
    this.text = 'OR',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? AppColors.textTertiaryDark.withValues(alpha: 0.3)
        : AppColors.textTertiary.withValues(alpha: 0.3);
    final textColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiary;

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: dividerColor,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: dividerColor,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}



