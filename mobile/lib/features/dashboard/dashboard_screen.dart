import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/app_empty_state.dart';
import '../../design_system/components/async_state_view.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../router/routes.dart';
import '../../domain/models/device.dart';
import '../../domain/rules/derived_alerts.dart';
import '../../domain/rules/fleet_status.dart';
import '../../state/devices_provider.dart';
import '../../state/session_provider.dart';
import '../../state/telemetry_provider.dart';
import 'state/fleet_kpis_provider.dart';
import 'widgets/fleet_metrics_section.dart';
import 'widgets/live_feed_section.dart';
import 'widgets/metrics_overview.dart';
import 'widgets/open_alerts_section.dart';
import 'widgets/problem_vehicles_section.dart';

/// DASH-1/DASH-2: "what is happening with my fleet right now" — KPIs,
/// vehicles with problems, recent alerts, activity. [devicesProvider] gates
/// the four-state contract (design §9), same pattern as `VehiclesScreen`;
/// [latestTelemetryProvider]/[fleetKpisProvider]/the live feed/alerts
/// sections never gate the view — a failure or in-flight fetch on any of
/// them just means that section renders with less data, not an error
/// screen.
///
/// Composition (design §2.4, no new tokens): the page is a single scrolling
/// column on the app background, not a stack of card surfaces. Depth comes
/// from type scale, whitespace and hairlines; the only elevated surfaces
/// left on this screen are the ones Material owns (bottom navigation,
/// sheets). Each block owns its own section header, so the screen reads
/// top-down as headline number -> what needs attention -> what just
/// happened.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final telemetryByDevice =
        ref.watch(latestTelemetryProvider).valueOrNull?.value ?? const {};
    final kpis = ref.watch(fleetKpisProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return AsyncStateView<List<Device>>(
      state: devicesAsync,
      isEmpty: (devices) => devices.isEmpty,
      data: (devices, cachedAt) {
        final problemVehicles = [
          for (final device in devices)
            ProblemVehicle(
              device: device,
              status: fleetOverlayStatus(device, telemetryByDevice[device.id]),
              reading: telemetryByDevice[device.id],
            ),
        ].where(_needsAttention).toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            _DashboardHeader(unreadCount: kpis.openAlertsCount),
            const SizedBox(height: AppSpacing.xl),
            MetricsOverview(kpis: kpis),
            if (problemVehicles.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              ProblemVehiclesSection(vehicles: problemVehicles),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const LiveFeedSection(),
            const SizedBox(height: AppSpacing.xxl),
            const FleetMetricsSection(),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.xxl),
              const OpenAlertsSection(),
            ],
          ],
        );
      },
      empty: const AppEmptyState(
        icon: Icons.local_shipping_outlined,
        title: AppStrings.dashboardEmptyFleetTitle,
        body: AppStrings.dashboardEmptyFleetBody,
      ),
      onRetry: () => ref.invalidate(devicesProvider),
    );
  }
}

/// Title, subtitle and the alerts shortcut. [unreadCount] is
/// [FleetKpis.openAlertsCount], which is null for a non-admin session
/// (ROLE-2) — the bell still routes to `/alerts`, it just carries no badge,
/// because a non-admin has no count to be told about.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.unreadCount});

  final int? unreadCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasUnread = (unreadCount ?? 0) > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.dashboardTitle,
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.dashboardSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Semantics(
          button: true,
          label: AppStrings.dashboardNotificationsLabel,
          child: InkWell(
            onTap: () => context.go(Routes.alerts),
            customBorder: const CircleBorder(),
            child: Container(
              // A11Y-1: 44dp of surface inside a 48dp tap box.
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 22,
                      color: AppColors.secondaryForeground,
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.ring,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.secondary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _needsAttention(ProblemVehicle vehicle) =>
    vehicle.status == FleetStatus.alert ||
    vehicle.status == FleetStatus.critical;
