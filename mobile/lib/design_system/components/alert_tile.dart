import 'package:flutter/material.dart';

import '../../core/time/app_format.dart';
import '../../domain/models/fleet_alert.dart';
import '../strings/app_strings.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// ALT-6: a single amber tone + fuel icon + verbatim server `message` —
/// never a severity badge/color-tier/icon derived from `fuel_level`/`speed`
/// (the VEH-5 overlay is a vehicle-list-only construct that must never
/// leak here, and `AlertRead` has no severity field to derive from
/// anyway). The one shared row for the alerts list, the vehicle detail's
/// Alertas tab, and the dashboard's open-alerts card — previously three
/// separate `_AlertRow`/`_OpenAlertRow` copies (slice 6 debt, now
/// consolidated).
class AlertTile extends StatelessWidget {
  const AlertTile({
    required this.alert,
    this.onTap,
    this.onResolve,
    this.resolveDisabledReason,
    this.emphasis = false,
    super.key,
  });

  final FleetAlert alert;
  final VoidCallback? onTap;

  /// Present only where resolve is offered (the alerts list / alert
  /// detail screen); left `null` everywhere else — the dashboard card and
  /// the vehicle detail's Alertas tab are read-only (VDET-4).
  final VoidCallback? onResolve;

  /// ALT-5: non-null disables the resolve control and carries the reason
  /// (e.g. offline) as its semantics label, instead of a tap silently
  /// doing nothing.
  final String? resolveDisabledReason;

  /// The vehicle detail's "Alertas activas" variant: the same row on a
  /// warning-tinted surface, with the alert's age and an affordance for
  /// the tap the plain row leaves implicit. Off everywhere else — on the
  /// alerts list and the dashboard the rows already sit inside a card and
  /// tinting each one would turn the whole surface amber.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final canResolve = onResolve != null && !alert.isResolved;

    final row = Padding(
      padding: emphasis
          ? const EdgeInsets.all(AppSpacing.md)
          : const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.local_gas_station, size: 16, color: colors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              alert.message,
              style: AppTypography.bodyMedium,
              maxLines: emphasis ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (emphasis) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppFormat.timeAgo(alert.createdAt),
              style: AppTypography.bodySmall.copyWith(
                color: colors.onWarningSoft,
              ),
              maxLines: 1,
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
          ],
          if (canResolve)
            Semantics(
              label: resolveDisabledReason ?? AppStrings.resolveAlertLabel,
              button: true,
              child: ExcludeSemantics(
                child: IconButton(
                  onPressed: resolveDisabledReason == null ? onResolve : null,
                  icon: const Icon(Icons.task_alt),
                  tooltip:
                      resolveDisabledReason ?? AppStrings.resolveAlertLabel,
                ),
              ),
            ),
        ],
      ),
    );

    final content = emphasis
        ? Container(
            decoration: BoxDecoration(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: row,
          )
        : row;

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(emphasis ? AppRadii.xl : AppRadii.md),
      child: content,
    );
  }
}
