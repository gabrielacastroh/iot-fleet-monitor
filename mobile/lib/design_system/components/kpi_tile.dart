import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_card.dart';

/// A generic `{icon, label, value}` dashboard tile (DASH-1's KPI row).
/// Deliberately dumb — no business logic, no per-metric variant; every KPI
/// (active count, average fuel, average temperature, open alerts) renders
/// through this same shape.
class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.dataLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
