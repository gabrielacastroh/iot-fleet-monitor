import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/app_format.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/status_tone.dart';
import '../../../design_system/components/section_link_header.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/device.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../domain/rules/fleet_status.dart';
import '../../../router/routes.dart';

/// One vehicle the dashboard is flagging, already resolved by the caller —
/// [status] is [fleetOverlayStatus]'s output, never recomputed here.
class ProblemVehicle {
  const ProblemVehicle({
    required this.device,
    required this.status,
    this.reading,
  });

  final Device device;
  final FleetStatus status;
  final TelemetryReading? reading;
}

/// DASH-2's "Vehículos con problemas": a card of rows, each one a tap
/// target onto that vehicle's detail route. A status-toned glyph and a
/// matching chip carry the state in two channels, and the reading that
/// earned the flag is the heaviest thing on the row.
class ProblemVehiclesSection extends StatelessWidget {
  const ProblemVehiclesSection({required this.vehicles, super.key});

  final List<ProblemVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLinkHeader(
          title: AppStrings.problemVehiclesSectionTitle,
          actionLabel: AppStrings.seeAllCountLabel(vehicles.length),
          onAction: () => context.go(Routes.vehicles),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, vehicle) in vehicles.indexed) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: AppColors.border,
                  ),
                _ProblemRow(vehicle: vehicle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.vehicle});

  final ProblemVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final device = vehicle.device;
    final reading = vehicle.reading;
    final tone = statusToneOf(context, vehicle.status);

    return MergeSemantics(
      child: InkWell(
        onTap: () => context.go(Routes.vehicleDetail(device.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A11Y-5: the glyph is the second channel next to the tone
              // colour, and the semantics label spells the state out for a
              // screen reader — colour alone never carries the status.
              Semantics(
                label: tone.label,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.softSurface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(tone.icon, size: 20, color: tone.softText),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.vehicleName, style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${device.plate} · ${device.deviceCode}',
                      style: AppTypography.dataMedium.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusChip(tone: tone),
                  ],
                ),
              ),
              if (reading != null) ...[
                const SizedBox(width: AppSpacing.sm),
                // Tight flex, so the reading column ends on the row's right
                // edge and wraps (never overflows) at large text scales.
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${reading.fuelLevel.round()}%',
                        style: AppTypography.dataStat.copyWith(
                          color: tone.softText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Stacked, not joined by a separator: at this column
                      // width a single line wraps mid-phrase, which reads as
                      // an accident rather than a layout.
                      Text(
                        '${reading.speed.round()} km/h',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        AppFormat.timeAgo(reading.recordedAt),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status word next to its dot. `ExcludeSemantics` because the glyph
/// above already announces [StatusTone.label] — without it a screen reader
/// reads the state twice per row.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tone});

  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          // A11Y-3: "Sin señal" outgrows this column at 2.0x text scale.
          Flexible(
            child: Text(
              tone.label,
              style: AppTypography.bodySmall.copyWith(color: tone.softText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
