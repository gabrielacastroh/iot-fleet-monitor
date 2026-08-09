import 'package:flutter/material.dart';

import '../../../core/time/app_format.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/device.dart';
import '../../../domain/models/fleet_alert.dart';

/// ALT-6, held: one amber tone, the fuel glyph, and the server's `message`
/// verbatim. The mockup's severity chip and per-type icons are deliberately
/// absent — `AlertRead` carries no severity, and `low_fuel` is its only
/// real `alert_type`, so both would be values this client invented.
///
/// The leading rule and the tinted glyph are the mockup's shape; what they
/// encode is resolved-vs-pending, which is a fact the row actually has.
class AlertListCard extends StatelessWidget {
  const AlertListCard({
    required this.alert,
    this.device,
    this.onTap,
    this.onResolve,
    this.resolveDisabledReason,
    super.key,
  });

  final FleetAlert alert;

  /// Joined by the caller so the row can name a vehicle instead of a raw
  /// `device_id`. Null when the fleet list hasn't loaded — the row falls
  /// back to the id rather than hiding the line.
  final Device? device;

  final VoidCallback? onTap;

  /// ALT-3: present only where resolve is offered.
  final VoidCallback? onResolve;

  /// ALT-5: non-null disables the resolve control and carries the reason
  /// (e.g. offline) instead of a tap silently doing nothing.
  final String? resolveDisabledReason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final canResolve = onResolve != null && !alert.isResolved;
    final accent = alert.isResolved
        ? colors.onSuccessSoft
        : colors.onWarningSoft;
    final surface = alert.isResolved ? colors.successSoft : colors.warningSoft;

    // Two actions live on this row, so it exposes two semantic nodes rather
    // than one merged blob: "open the alert" (the tappable body) and
    // "resolve" (ALT-3's button). `VehicleCard` can merge because it has no
    // control inside it; merging here would leave a screen-reader user able
    // to open an alert but not to resolve one.
    final body = Semantics(
      button: onTap != null,
      label: _semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Icon(Icons.local_gas_station, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alert.message,
                    style: AppTypography.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppFormat.timeAgo(alert.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The mockup's leading rule. `stretch` + `IntrinsicHeight` so
              // it spans whatever the row grows to at large text scales,
              // instead of a fixed height that stops short.
              Container(width: 4, color: accent),
              // The resolve button sits OUTSIDE this InkWell, so tapping it
              // resolves the alert instead of also opening its detail.
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: body,
                  ),
                ),
              ),
              if (canResolve)
                Semantics(
                  label:
                      resolveDisabledReason ?? AppStrings.resolveAlertLabel,
                  button: true,
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: IconButton(
                        onPressed: resolveDisabledReason == null
                            ? onResolve
                            : null,
                        icon: const Icon(Icons.task_alt, size: 20),
                        tooltip:
                            resolveDisabledReason ??
                            AppStrings.resolveAlertLabel,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One sentence for the tappable body, since [ExcludeSemantics] hides the
  /// individual `Text`s that would otherwise be read one node at a time.
  String get _semanticsLabel => '${alert.message}. $_subtitle';

  String get _subtitle {
    final resolved = device;
    if (resolved == null) return alert.deviceId;
    return '${resolved.vehicleName} · ${resolved.plate} · '
        '${resolved.deviceCode}';
  }
}
