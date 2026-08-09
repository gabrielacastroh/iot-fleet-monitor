import 'package:flutter/material.dart';

import '../../../core/time/app_format.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/fuel_tone.dart';
import '../../../design_system/status_tone.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/device.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../domain/rules/fleet_status.dart';

/// VDET-1/VDET-2: the vehicle detail's opening card — when the vehicle
/// last reported, and the four numbers that answer "is it fine right now"
/// (fuel, speed, temperature, staleness) without scrolling.
///
/// [device] and [status] are resolved by the caller
/// (`VehicleDetailScreen`) from the already-loaded `devicesProvider` list,
/// the same pattern `VehicleCard` uses on the list screen.
class VehicleHeroCard extends StatelessWidget {
  const VehicleHeroCard({
    required this.device,
    required this.status,
    this.reading,
    super.key,
  });

  final Device device;
  final FleetStatus status;
  final TelemetryReading? reading;

  /// Below this the four tiles are narrower than the widest label
  /// ("Desde última señal") can break to, so they go two by two instead.
  static const _fourColumnMinWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    final tone = statusToneOf(context, status);
    final lastReportedAt = reading?.recordedAt ?? device.lastSeenAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LastUpdateRow(tone: tone, lastReportedAt: lastReportedAt),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
          if (device.lastSeenAt == null)
            const _NeverReportedRow()
          else
            LayoutBuilder(
              builder: (context, constraints) => _MetricRow(
                tiles: _tiles(context, lastReportedAt),
                columns: constraints.maxWidth < _fourColumnMinWidth ? 2 : 4,
              ),
            ),
        ],
      ),
    );
  }

  List<_MetricTile> _tiles(BuildContext context, DateTime? lastReportedAt) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final value = reading;
    // Same thresholds as `fleetOverlayStatus`, so the tile never disagrees
    // with the status pill in the app bar.
    final fuelTone = value == null
        ? fuelToneUnknown
        : fuelToneOf(context, value.fuelLevel);

    return [
      _MetricTile(
        icon: Icons.local_gas_station_outlined,
        tint: fuelTone.text,
        tintSurface: fuelTone.surface,
        value: value == null
            ? AppStrings.kpiNoDataValue
            : '${value.fuelLevel.round()}',
        unit: value == null ? '' : '%',
        label: AppStrings.vehiclesFuelLabel,
      ),
      _MetricTile(
        icon: Icons.speed_outlined,
        tint: AppColors.primary,
        tintSurface: AppColors.primarySoft,
        value: value == null
            ? AppStrings.kpiNoDataValue
            : '${value.speed.round()}',
        unit: value == null ? '' : ' km/h',
        label: AppStrings.vehiclesSpeedLabel,
      ),
      _MetricTile(
        icon: Icons.thermostat_outlined,
        // The mockup tints this one violet; the palette has no violet, and
        // inventing one would put a colour on screen that means nothing
        // anywhere else in the app (same call as the dashboard KPIs).
        tint: AppColors.primary,
        tintSurface: AppColors.primarySoft,
        value: value == null
            ? AppStrings.kpiNoDataValue
            : '${value.temperature.round()}',
        unit: value == null ? '' : '°C',
        label: AppStrings.vehicleTemperatureLabel,
      ),
      _MetricTile(
        icon: Icons.schedule_outlined,
        tint: colors.sidebarMuted,
        tintSurface: AppColors.secondary,
        value: AppFormat.shortAge(lastReportedAt),
        unit: '',
        label: AppStrings.vehicleSinceLastSignalLabel,
      ),
    ];
  }
}

class _LastUpdateRow extends StatelessWidget {
  const _LastUpdateRow({required this.tone, required this.lastReportedAt});

  final StatusTone tone;
  final DateTime? lastReportedAt;

  @override
  Widget build(BuildContext context) {
    final reportedAt = lastReportedAt;

    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tone.softSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 26,
                  color: tone.softText,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tone.dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.vehicleLastUpdateLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  AppFormat.timeAgo(reportedAt),
                  style: AppTypography.dataStat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reportedAt != null)
                  Text(
                    AppFormat.clockAndDate(reportedAt),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NeverReportedRow extends StatelessWidget {
  const _NeverReportedRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sensors_off, color: AppColors.mutedForeground),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            AppStrings.neverReportedMessage,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tiles laid out on a fixed column count so every value sits on the
/// same baseline grid regardless of how long its label breaks.
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.tiles, required this.columns});

  final List<_MetricTile> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_MetricTile>>[
      for (var i = 0; i < tiles.length; i += columns)
        tiles.sublist(i, (i + columns).clamp(0, tiles.length)),
    ];

    return Column(
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns; i++)
                  Expanded(
                    child: i < row.length ? row[i] : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.tint,
    required this.tintSurface,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final Color tintSurface;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tintSurface, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  text: value,
                  style: AppTypography.dataStat.copyWith(color: tint),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: unit,
                        style: AppTypography.bodySmall.copyWith(color: tint),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
