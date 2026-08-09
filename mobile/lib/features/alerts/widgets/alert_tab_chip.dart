import 'package:flutter/material.dart';

import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../state/alert_filter_provider.dart';

/// One triage chip. Not the shared `StatusFilterChip`: that one speaks the
/// vehicle `FleetStatus` vocabulary (tone dots per state), and these three
/// tabs are an `is_resolved` filter, not a fleet state. ALT-6 also rules
/// out giving them status tones — an alert has no severity to tone.
///
/// [count] is nullable on purpose. The Resueltas/Todas feeds are uncached,
/// online-only passthroughs (design §5.3), so before their tab has been
/// opened there is no honest number to show — the chip renders without one
/// rather than printing a `0` the user would read as "none".
class AlertTabChip extends StatelessWidget {
  const AlertTabChip({
    required this.tab,
    required this.isSelected,
    required this.count,
    required this.onTap,
    super.key,
  });

  final AlertListTab tab;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isPending = tab == AlertListTab.pending;
    // Pending is the only tab that carries a tone, and it is the tone of
    // "unresolved work", not of a severity (ALT-6).
    final accent = isPending ? colors.onWarningSoft : AppColors.primary;
    final surface = isPending ? colors.warningSoft : AppColors.primarySoft;
    final foreground = isSelected ? accent : AppColors.secondaryForeground;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: AppSpacing.sm,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? surface : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            border: Border.all(color: isSelected ? accent : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 15, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  _label,
                  style: AppTypography.bodySmall.copyWith(
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$count',
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected ? accent : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (tab) {
    AlertListTab.pending => Icons.notifications_none,
    AlertListTab.resolved => Icons.check_circle_outline,
    AlertListTab.all => Icons.layers_outlined,
  };

  String get _label => switch (tab) {
    AlertListTab.pending => AppStrings.alertsTabPending,
    AlertListTab.resolved => AppStrings.alertsTabResolved,
    AlertListTab.all => AppStrings.alertsTabAll,
  };
}
