import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// The micro-label above every panel group — port of the web's `.eyebrow`
/// pattern, promoted to a titled section header.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
