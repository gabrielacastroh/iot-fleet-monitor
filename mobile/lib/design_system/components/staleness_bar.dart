import 'package:flutter/material.dart';

import '../../core/time/app_format.dart';
import '../strings/app_strings.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// OFF-4: "Sin conexión · datos de hace {timeAgo}" — shown over cached
/// content whenever a screen paints from cache (offline, or a refresh that
/// failed but left the previous value in place).
class StalenessBar extends StatelessWidget {
  const StalenessBar({required this.cachedAt, super.key});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: colors.warningSoft,
      child: Text(
        AppStrings.stalenessMessage(AppFormat.timeAgo(cachedAt)),
        style: AppTypography.bodySmall.copyWith(color: colors.onWarningSoft),
      ),
    );
  }
}
