import 'package:flutter/material.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/rules/fleet_kpis.dart';

/// DASH-1's KPIs in two surfaces: the active-vehicle count as a wide hero
/// card carrying the screen's single largest number, and the remaining
/// metrics as one card split into equal columns by hairlines.
///
/// Same data and same ROLE-2 gating as before — "Alertas abiertas" still
/// appears only when [FleetKpis.openAlertsCount] is non-null; only the
/// composition changed.
class MetricsOverview extends StatelessWidget {
  const MetricsOverview({required this.kpis, super.key});

  final FleetKpis kpis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final openAlertsCount = kpis.openAlertsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(kpis: kpis, colors: colors),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.local_gas_station_outlined,
                    tint: colors.onSuccessSoft,
                    tintSurface: colors.successSoft,
                    label: AppStrings.kpiAverageFuelLabel,
                    value: _percent(kpis.averageFuelLevel),
                  ),
                ),
                const _ColumnRule(),
                Expanded(
                  child: _StatTile(
                    icon: Icons.thermostat_outlined,
                    // The mockup tints this one violet; the palette has no
                    // violet, and inventing one would put a colour on screen
                    // that means nothing anywhere else in the app.
                    tint: AppColors.primary,
                    tintSurface: AppColors.primarySoft,
                    label: AppStrings.kpiAverageTemperatureLabel,
                    value: _degrees(kpis.averageTemperature),
                  ),
                ),
                if (openAlertsCount != null) ...[
                  const _ColumnRule(),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.warning_amber_rounded,
                      tint: colors.onWarningSoft,
                      tintSurface: colors.warningSoft,
                      label: AppStrings.kpiOpenAlertsLabel,
                      value: '$openAlertsCount',
                      // The only metric allowed to colour its value, and
                      // only when there is something to act on. The label
                      // still names it, so colour is never the only
                      // channel (A11Y-5).
                      valueColor: openAlertsCount > 0
                          ? colors.onWarningSoft
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The screen's headline number. The route trace behind it is decoration
/// drawn from tokens, not a real map — it exists so the hero reads as fleet
/// telemetry rather than as a number in a box.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.kpis, required this.colors});

  final FleetKpis kpis;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteTracePainter(
                  line: AppColors.border,
                  marker: AppColors.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppStrings.kpiActiveVehiclesLabel,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          Text(
                            '${kpis.activeCount}',
                            style: AppTypography.dataHero,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: colors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              // A11Y-3: at 2.0x this line is wider than the
                              // hero's text column, and a bare `Text` in a
                              // `MainAxisSize.min` row cannot give ground.
                              Flexible(
                                child: Text(
                                  AppStrings.kpiOnlineNowLabel,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: colors.onSuccessSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faint street grid with three vehicle pins in the card's right third —
/// the mockup's map vignette. Purely decorative, so it is excluded from
/// semantics by the caller's [MergeSemantics] having nothing to merge here.
class _RouteTracePainter extends CustomPainter {
  const _RouteTracePainter({required this.line, required this.marker});

  final Color line;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = line;

    // Diagonal streets, clipped to the right third so they never run under
    // the number.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(size.width * 0.52, 0, size.width * 0.48, size.height),
    );
    for (final start in [0.30, 0.52, 0.74, 0.96]) {
      canvas.drawLine(
        Offset(size.width * start, -size.height * 0.2),
        Offset(size.width * (start + 0.30), size.height * 1.2),
        stroke,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.62),
      Offset(size.width, size.height * 0.38),
      stroke,
    );
    canvas.restore();

    final halo = Paint()..color = marker.withValues(alpha: 0.10);
    final pin = Paint()..color = marker;
    for (final (center, radius) in [
      (Offset(size.width * 0.70, size.height * 0.60), 16.0),
      (Offset(size.width * 0.83, size.height * 0.28), 0.0),
      (Offset(size.width * 0.94, size.height * 0.62), 14.0),
    ]) {
      if (radius > 0) canvas.drawCircle(center, radius, halo);
      canvas.drawCircle(center, 4.5, pin);
    }
  }

  @override
  bool shouldRepaint(_RouteTracePainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.marker != marker;
}

class _ColumnRule extends StatelessWidget {
  const _ColumnRule();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      width: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 0,
      endIndent: 0,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.tintSurface,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color tint;
  final Color tintSurface;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tintSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.dataStat.copyWith(color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}

String _percent(double? value) =>
    value == null ? AppStrings.kpiNoDataValue : '${value.round()}%';

String _degrees(double? value) =>
    value == null ? AppStrings.kpiNoDataValue : '${value.round()}°C';
