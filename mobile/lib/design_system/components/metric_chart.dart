import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/time/app_format.dart';
import '../../domain/models/telemetry_reading.dart';
import '../strings/app_strings.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_card.dart';
import 'app_empty_state.dart';

/// Which end of the series the card highlights next to its average — fuel
/// is read by how low it got, speed and temperature by how high.
enum MetricExtreme { max, min }

/// A single-series line chart over a telemetry history (the vehicle
/// detail's Telemetría section: speed/fuel/temperature), on its own card:
/// a tinted metric icon, the title, the series average, and the highlighted
/// extreme, over an area chart with labelled value and date axes.
///
/// Renders [AppEmptyState] when [readings] is empty (VDET-6's
/// precondition) instead of a blank chart. Tap — not hover, mobile has no
/// pointer — shows the tooltip via `fl_chart`'s built-in touch handling.
class MetricChart extends StatelessWidget {
  const MetricChart({
    required this.title,
    required this.readings,
    required this.valueOf,
    required this.unit,
    required this.color,
    required this.icon,
    required this.tintSurface,
    this.extreme = MetricExtreme.max,
    this.labelOf,
    super.key,
  });

  final String title;
  final List<TelemetryReading> readings;
  final double Function(TelemetryReading reading) valueOf;
  final String unit;
  final Color color;
  final IconData icon;
  final Color tintSurface;
  final MetricExtreme extreme;
  final String Function(DateTime)? labelOf;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return AppEmptyState(
        icon: Icons.show_chart,
        title: title,
        body: AppStrings.noReadingsInRangeMessage,
      );
    }

    final values = [for (final reading in readings) valueOf(reading)];
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final average = values.reduce((a, b) => a + b) / values.length;
    final extremeValue = extreme == MetricExtreme.max
        ? values.reduce((a, b) => a > b ? a : b)
        : values.reduce((a, b) => a < b ? a : b);
    final maxY = _axisMax(values.reduce((a, b) => a > b ? a : b));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: title,
            icon: icon,
            color: color,
            tintSurface: tintSurface,
            average: AppStrings.chartAverageLabel(_format(average)),
            extreme: extreme == MetricExtreme.max
                ? AppStrings.chartMaxLabel(_format(extremeValue))
                : AppStrings.chartMinLabel(_format(extremeValue)),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 2,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: maxY / 2,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: AppSpacing.sm,
                        child: Text(
                          '${value.round()}',
                          style: _axisStyle,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: _dateTickInterval(readings.length),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= readings.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          space: AppSpacing.sm,
                          child: Text(
                            (labelOf ?? AppFormat.dayMonth)(
                              readings[index].recordedAt,
                            ),
                            style: _axisStyle,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => [
                      for (final spot in touchedSpots)
                        LineTooltipItem(
                          '${spot.y.round()}$unit',
                          const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.18),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(double value) => '${value.round()}$unit';
}

const _axisStyle = TextStyle(
  fontFamily: 'Geist',
  fontSize: 11,
  height: 16 / 11,
  fontWeight: FontWeight.w500,
  color: AppColors.mutedForeground,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// A round value at or above the series peak that divides cleanly into the
/// three axis labels the card shows (0, half, max): 98 -> 100, 68 -> 80.
double _axisMax(double peak) {
  if (peak <= 0) return 4;
  const steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000];
  for (final step in steps) {
    if (step * 4 >= peak) return step * 4;
  }
  return (peak / 1000).ceilToDouble() * 1000;
}

/// Four date ticks at most — the axis is there to say which week the line
/// covers, not to be read point by point.
double _dateTickInterval(int count) {
  if (count <= 1) return 1;
  return ((count - 1) / 3).ceilToDouble();
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.icon,
    required this.color,
    required this.tintSurface,
    required this.average,
    required this.extreme,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color tintSurface;
  final String average;
  final String extreme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tintSurface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  average,
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
        const SizedBox(width: AppSpacing.sm),
        Text(
          extreme,
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
