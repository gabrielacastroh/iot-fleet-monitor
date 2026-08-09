import 'package:flutter/material.dart';

import '../../../core/time/app_format.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/status_badge.dart';
import '../../../design_system/fuel_tone.dart';
import '../../../design_system/status_tone.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_durations.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_shadows.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../state/map_markers_provider.dart';

/// MAP-3's vehicle sheet: the card that rises over the map when a marker is
/// tapped. Not a modal — a modal would grey out and swallow the map the
/// sheet is describing, and the point of tapping a marker is to look at
/// where the vehicle is while reading its numbers.
///
/// Collapsed it shows identity, state and the two numbers that decide
/// whether to act (fuel, speed). Expanded it adds when the reading arrived
/// and where the vehicle is, plus the link to the full detail. The drag
/// handle toggles between the two; dragging down past the collapsed state
/// dismisses it.
class MapVehicleSheet extends StatelessWidget {
  const MapVehicleSheet({
    required this.marker,
    required this.isExpanded,
    required this.onToggle,
    required this.onDismiss,
    required this.onOpenDetail,
    super.key,
  });

  final VehicleMarker marker;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;
  final VoidCallback onOpenDetail;

  /// The sheet is a card, not a wall: on a tablet it stays the width of a
  /// phone sheet instead of stretching across the whole map.
  static const maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final tone = statusToneOf(context, marker.status);
    final reading = marker.reading;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            boxShadow: AppShadows.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DragHandle(
                isExpanded: isExpanded,
                onToggle: onToggle,
                onDismiss: onDismiss,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(marker: marker, tone: tone),
                    AnimatedSize(
                      duration: AppDurations.of(context, AppDurations.base),
                      curve: AppDurations.enterCurve,
                      alignment: Alignment.topCenter,
                      child: isExpanded
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),
                                ),
                                _DetailsRow(
                                  recordedAt: reading.recordedAt,
                                  latitude: reading.latitude,
                                  longitude: reading.longitude,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                AppButton(
                                  label: AppStrings.mapViewDetailLabel,
                                  onPressed: onOpenDetail,
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.isExpanded,
    required this.onToggle,
    required this.onDismiss,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;

  /// Anything softer than this reads as a tap that missed, not a swipe.
  static const _dismissVelocity = 250.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isExpanded
          ? AppStrings.mapSheetCollapseLabel
          : AppStrings.mapSheetExpandLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -_dismissVelocity && !isExpanded) return onToggle();
            if (velocity > _dismissVelocity) {
              return isExpanded ? onToggle() : onDismiss();
            }
          },
          child: SizedBox(
            // A11Y-1: the visible bar is 4dp tall; the target is not.
            height: 28,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.marker, required this.tone});

  final VehicleMarker marker;
  final StatusTone tone;

  /// Below this the identity column and the two metrics don't fit on one
  /// line: measured on a 400dp phone, where the card's inner width is
  /// 344dp and the row overflowed by 36px.
  static const _inlineMetricsMinWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          children: [
            _Avatar(tone: tone),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      marker.device.vehicleName,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${marker.device.plate} · ${marker.device.deviceCode}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(status: marker.status),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        final metrics = _Metrics(reading: marker.reading);

        if (constraints.maxWidth < _inlineMetricsMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              identity,
              const SizedBox(height: AppSpacing.lg),
              metrics,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: metrics),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.tone});

  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.softSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 22,
              color: tone.softText,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
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
    );
  }
}

/// Fuel and speed, split by a hairline — the pair that decides whether this
/// vehicle needs attention before opening its detail.
class _Metrics extends StatelessWidget {
  const _Metrics({required this.reading});

  final TelemetryReading reading;

  @override
  Widget build(BuildContext context) {
    final fuelTone = fuelToneOf(context, reading.fuelLevel);

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Metric(
            value: '${reading.fuelLevel.round()}%',
            label: AppStrings.vehiclesFuelLabel,
            valueColor: fuelTone.text,
          ),
          const VerticalDivider(
            width: AppSpacing.xl,
            thickness: 1,
            color: AppColors.border,
          ),
          _Metric(
            value: '${reading.speed.round()} km/h',
            label: AppStrings.vehiclesSpeedLabel,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: AppTypography.dataStat.copyWith(color: valueColor),
            maxLines: 1,
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mutedForeground,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
  });

  final DateTime recordedAt;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DetailItem(
            icon: Icons.schedule_outlined,
            label: AppStrings.vehicleLastUpdateLabel,
            value: AppFormat.timeAgo(recordedAt),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _DetailItem(
            icon: Icons.place_outlined,
            label: AppStrings.mapLocationLabel,
            // No reverse geocoding exists in this app — the coordinates are
            // shown as they arrived rather than a guessed place name.
            value: AppStrings.mapCoordinatesLabel(latitude, longitude),
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: AppTypography.dataMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
