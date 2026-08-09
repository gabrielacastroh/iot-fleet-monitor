import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// OFF-2: a persistent "Sin conexión" badge mounted above the shell body
/// (shifts content down, never covers it). Announced once via a live
/// region — the condition persists, so this is a badge, not a toast.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        height: 32,
        color: colors.warningSoft,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 16, color: colors.onWarningSoft),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.offlineBadgeMessage,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onWarningSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
