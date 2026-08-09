import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_format.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/section_link_header.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../state/devices_provider.dart';
import '../../../state/realtime_provider.dart';

/// WS-6's rolling live feed (the dashboard's "recent activity"), joined
/// against [devicesProvider] so rows show a vehicle name rather than a raw
/// `device_id`. Shows only the most recent few — the feed itself stays
/// capped at 200 for other consumers, not for display here.
///
/// The header carries no "Ver todo" action: there is no full activity
/// screen to route to, and a link that goes nowhere is worse than no link.
class LiveFeedSection extends ConsumerWidget {
  const LiveFeedSection({super.key});

  static const _visibleCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(liveFeedProvider).valueOrNull ?? const [];
    final devices = ref.watch(devicesProvider).valueOrNull?.value ?? const [];
    final nameByDeviceId = {
      for (final device in devices) device.id: device.vehicleName,
    };
    final visible = feed.take(_visibleCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLinkHeader(title: AppStrings.liveFeedSectionTitle),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          const _LiveFeedEmpty()
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, reading) in visible.indexed) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: AppColors.border,
                    ),
                  _LiveFeedRow(
                    vehicleName:
                        nameByDeviceId[reading.deviceId] ?? reading.deviceId,
                    reading: reading,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A recessed surface rather than a card: nothing has happened yet, so the
/// block should read as an absence, not as content with a raised edge.
class _LiveFeedEmpty extends StatelessWidget {
  const _LiveFeedEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sensors_off,
            size: 20,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.liveFeedEmptyBody,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveFeedRow extends StatelessWidget {
  const _LiveFeedRow({required this.vehicleName, required this.reading});

  final String vehicleName;
  final TelemetryReading reading;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Tight flex on both sides (not a loose `Flexible`): the value
            // column must actually fill its share so `TextAlign.end` lands
            // on the row's right edge, and so it wraps instead of
            // overflowing at large text scales.
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleName,
                    style: AppTypography.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppFormat.timeAgo(reading.recordedAt),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                '${reading.speed.round()} km/h · '
                '${reading.fuelLevel.round()}%',
                style: AppTypography.dataMedium,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
