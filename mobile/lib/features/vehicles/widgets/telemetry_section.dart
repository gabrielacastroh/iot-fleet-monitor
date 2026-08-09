import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_empty_state.dart';
import '../../../design_system/components/app_error_state.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/date_range_field.dart';
import '../../../design_system/components/metric_chart.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../domain/rules/date_range.dart';
import '../../../state/telemetry_provider.dart';
import 'route_map.dart';

/// VDET-3/VDET-5: date-range input + speed/fuel/temperature charts + the
/// route map, all sourced from one uncached [telemetryHistoryProvider]
/// fetch.
///
/// This section resolves the four states itself instead of delegating to
/// `AsyncStateView`: it lives inside the detail screen's scroll view, where
/// height is unbounded, and every non-data state that component renders
/// (`AppSkeleton`, `AppEmptyState`, `AppErrorState`) expects a bounded
/// viewport to centre itself in. History is never cached (design §5.3), so
/// there is no previous value to key the offline fork off either — OFF-3b
/// (offline, no prior fetch for this range) is its own branch below.
class TelemetrySection extends ConsumerStatefulWidget {
  const TelemetrySection({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<TelemetrySection> createState() => _TelemetrySectionState();
}

class _TelemetrySectionState extends ConsumerState<TelemetrySection> {
  int _selectedDays = defaultRangeDays;

  /// The height every non-data state occupies, so switching ranges doesn't
  /// make the page jump between a skeleton and three charts.
  static const _placeholderHeight = 220.0;

  /// Below this the title and the 7d/30d/90d control don't fit on one line.
  static const _inlineRangeMinWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    final range = rangeFromDays(_selectedDays);
    final query = HistoryQuery(
      deviceId: widget.deviceId,
      startDate: range.startDate,
      endDate: range.endDate,
    );
    final historyAsync = ref.watch(telemetryHistoryProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              AppStrings.telemetrySectionTitle,
              style: AppTypography.titleMedium,
            );
            final rangeField = DateRangeField(
              selectedDays: _selectedDays,
              onChanged: (days) => setState(() => _selectedDays = days),
            );

            if (constraints.maxWidth < _inlineRangeMinWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: rangeField),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.md),
                rangeField,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _content(historyAsync, query),
      ],
    );
  }

  Widget _content(
    AsyncValue<List<TelemetryReading>> historyAsync,
    HistoryQuery query,
  ) {
    if (historyAsync.hasError) {
      // `hasError` guarantees a non-null error; the `!` is what lets it
      // reach `UnknownFailure(cause:)`, which takes a non-nullable Object.
      final error = historyAsync.error!;
      if (error is NetworkFailure) {
        return const _Placeholder(
          height: _placeholderHeight,
          child: AppEmptyState(
            icon: Icons.cloud_off,
            title: AppStrings.offlineBadgeMessage,
            body: AppStrings.offlineNoCacheMessage,
          ),
        );
      }
      return _Placeholder(
        height: _placeholderHeight,
        child: AppErrorState(
          failure: error is Failure ? error : UnknownFailure(cause: error),
          onRetry: () => ref.invalidate(telemetryHistoryProvider(query)),
        ),
      );
    }

    final readings = historyAsync.valueOrNull;
    if (readings == null) {
      return const _Placeholder(
        height: _placeholderHeight,
        child: AppSkeleton(lineCount: 6),
      );
    }
    if (readings.isEmpty) {
      return const _Placeholder(
        height: _placeholderHeight,
        child: AppEmptyState(
          icon: Icons.show_chart,
          title: AppStrings.telemetryEmptyTitle,
          body: AppStrings.noReadingsInRangeMessage,
        ),
      );
    }

    return _Charts(readings: readings);
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.readings});

  final List<TelemetryReading> readings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricChart(
          title: AppStrings.chartSpeedTitle,
          readings: readings,
          valueOf: (r) => r.speed,
          unit: ' km/h',
          color: AppColors.primary,
          icon: Icons.speed_outlined,
          tintSurface: AppColors.primarySoft,
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
          // Fuel is read by how low it got, not how high.
          extreme: MetricExtreme.min,
        ),
        const SizedBox(height: AppSpacing.md),
        MetricChart(
          title: AppStrings.chartTemperatureTitle,
          readings: readings,
          valueOf: (r) => r.temperature,
          unit: '°C',
          color: colors.onWarningSoft,
          icon: Icons.thermostat_outlined,
          tintSurface: colors.warningSoft,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.routeMapTitle,
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              // The map's own empty branch centres itself, so it needs the
              // same bounded box the map itself occupies.
              SizedBox(height: 240, child: RouteMap(readings: readings)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(child: SizedBox(height: height, child: child));
  }
}
