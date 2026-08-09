import 'package:flutter/material.dart';

import '../../core/time/app_format.dart';
import '../../domain/models/device.dart';
import '../../domain/models/telemetry_reading.dart';
import '../../domain/rules/fleet_status.dart';
import '../status_tone.dart';
import '../strings/app_strings.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_card.dart';
import 'status_badge.dart';

/// One row of the vehicles list (VEH-1): a status-toned vehicle avatar, the
/// name / plate / `device_code` line (opaque, rendered as-is, never parsed)
/// and its status badge on the left; the latest reading, labelled, on the
/// right. No business logic lives here — [fleetOverlayStatus] is computed by
/// the caller and passed in.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.device,
    required this.status,
    this.latestReading,
    this.socketOpen = false,
    this.onTap,
    super.key,
  });

  final Device device;
  final FleetStatus status;
  final TelemetryReading? latestReading;
  final bool socketOpen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reading = latestReading;
    final tone = statusToneOf(context, status);

    // A11Y-4: the whole card is one tap target once [onTap] is wired
    // (RESP-1's two-pane selection) — `MergeSemantics` folds every
    // descendant's semantics (name, plate/code, status) into that single
    // node instead of leaving it an unlabeled tappable region.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VehicleAvatar(tone: tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.vehicleName,
                      style: AppTypography.titleMedium,
                      // Two lines is a name; three is a paragraph that
                      // doubles the row height for one long vehicle.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${device.plate} · ${device.deviceCode}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StatusPill(status: status, socketOpen: socketOpen),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Always rendered, even with no reading: the em dashes say
              // "no data yet" in the same slot the numbers occupy, so rows
              // stay on one grid instead of collapsing to different widths.
              //
              // ponytail: fixed 5:4 split, not a breakpoint. It leaves the
              // reading column ~83dp at 375dp (the narrowest phone still
              // supported) against ~74dp of "Combustible", so it fits
              // everywhere current. Below ~340dp the label ellipsises — if
              // that ever matters, stack the two blocks vertically under a
              // `LayoutBuilder` rather than shrinking the type further.
              Expanded(flex: 4, child: _ReadingSummary(reading: reading)),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleAvatar extends StatelessWidget {
  const _VehicleAvatar({required this.tone});

  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.softSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 20,
              color: tone.softText,
            ),
          ),
          // The dot repeats the state the pill already spells out, at the
          // scanning distance where the pill's text is unreadable.
          Positioned(
            top: -2,
            left: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: tone.dot,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingSummary extends StatelessWidget {
  const _ReadingSummary({required this.reading});

  final TelemetryReading? reading;

  @override
  Widget build(BuildContext context) {
    final value = reading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Metric(
            icon: Icons.local_gas_station_outlined,
            value: value == null
                ? AppStrings.kpiNoDataValue
                : '${value.fuelLevel.round()}%',
            label: AppStrings.vehiclesFuelLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Metric(
            icon: Icons.speed_outlined,
            value: value == null
                ? AppStrings.kpiNoDataValue
                : '${value.speed.round()} km/h',
            label: AppStrings.vehiclesSpeedLabel,
          ),
          if (value != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppFormat.timeAgo(value.recordedAt),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    // The label sits under the whole {icon, value} pair rather than inside
    // the row beside it. Indenting it past the icon left "Combustible"
    // about 65dp on a 390dp phone, which is where it broke to two lines.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.mutedForeground),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                value,
                style: AppTypography.dataMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.mutedForeground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
