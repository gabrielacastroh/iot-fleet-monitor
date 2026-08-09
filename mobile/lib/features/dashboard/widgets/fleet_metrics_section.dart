import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_format.dart';
import '../../../design_system/components/metric_chart.dart';
import '../../../design_system/components/section_link_header.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../state/realtime_provider.dart';

/// Speed/fuel charts over the same rolling live-feed window as
/// [LiveFeedSection] (WS-6's fleet-wide, cross-device [liveFeedProvider]) —
/// not a new fetch, just a different view of it.
///
/// The header carries no "Ver todo" action: there is no dedicated metrics
/// screen to route to, and a link that goes nowhere is worse than no link.
class FleetMetricsSection extends ConsumerWidget {
  const FleetMetricsSection({super.key});

  static const _windowSize = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    // liveFeedProvider is newest-first (for feed display); MetricChart plots
    // oldest->newest by index, so the window has to be reversed.
    final readings =
        (ref.watch(liveFeedProvider).valueOrNull ?? const <TelemetryReading>[])
            .take(_windowSize)
            .toList()
            .reversed
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLinkHeader(title: AppStrings.fleetMetricsSectionTitle),
        const SizedBox(height: AppSpacing.md),
        MetricChart(
          title: AppStrings.chartSpeedTitle,
          readings: readings,
          valueOf: (r) => r.speed,
          unit: ' km/h',
          color: AppColors.primary,
          icon: Icons.speed_outlined,
          tintSurface: AppColors.primarySoft,
          labelOf: AppFormat.clock,
        ),
        const SizedBox(height: AppSpacing.md),
        MetricChart(
          title: AppStrings.chartFuelTitle,
          readings: readings,
          valueOf: (r) => r.fuelLevel,
          unit: '%',
          color: colors.onSuccessSoft,
          icon: Icons.local_gas_station_outlined,
          tintSurface: colors.successSoft,
          extreme: MetricExtreme.min,
          labelOf: AppFormat.clock,
        ),
      ],
    );
  }
}
