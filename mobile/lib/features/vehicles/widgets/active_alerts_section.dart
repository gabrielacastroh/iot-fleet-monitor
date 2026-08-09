import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../design_system/components/alert_tile.dart';
import '../../../design_system/components/app_error_state.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/section_link_header.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/fleet_alert.dart';
import '../../../router/routes.dart';
import '../../../state/alerts_provider.dart';

/// VDET-4: `GET /alerts/{device_id}`, admin-only. The caller
/// (`VehicleDetailScreen`) only mounts this widget inside an
/// `isAdminProvider` branch, so [deviceAlertsProvider] is never
/// constructed — and the request never fires — for a non-admin session
/// (same discipline as ROLE-2/`AlertsNotifier`).
///
/// Read-only here: resolving happens on the alerts screen (ALT-5), which
/// is where "Ver todas" leads.
class ActiveAlertsSection extends ConsumerWidget {
  const ActiveAlertsSection({required this.deviceId, super.key});

  final String deviceId;

  /// Enough to say "this vehicle needs attention" without turning the
  /// detail screen into a second alerts list.
  static const _visibleCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(deviceAlertsProvider(deviceId));
    final open = [
      for (final alert in alertsAsync.valueOrNull ?? const <FleetAlert>[])
        if (!alert.isResolved) alert,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLinkHeader(
          title: AppStrings.activeAlertsSectionTitle,
          actionLabel: open.isEmpty
              ? null
              : AppStrings.alertsViewAllCountLabel(open.length),
          onAction: open.isEmpty ? null : () => context.go(Routes.alerts),
        ),
        const SizedBox(height: AppSpacing.md),
        _content(context, ref, alertsAsync, open),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FleetAlert>> alertsAsync,
    List<FleetAlert> open,
  ) {
    if (alertsAsync.hasError) {
      final error = alertsAsync.error!;
      return SizedBox(
        height: 160,
        child: AppErrorState(
          failure: error is Failure ? error : UnknownFailure(cause: error),
          onRetry: () => ref.invalidate(deviceAlertsProvider(deviceId)),
        ),
      );
    }

    if (alertsAsync.isLoading) return const AppSkeleton(lineCount: 2);

    if (open.isEmpty) return const _AllClear();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, alert) in open.take(_visibleCount).indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          AlertTile(
            alert: alert,
            emphasis: true,
            onTap: () => context.push(
              Routes.alertDetail(alert.id, deviceId: deviceId),
            ),
          ),
        ],
      ],
    );
  }
}

/// A recessed surface rather than a card, matching the dashboard's
/// open-alerts empty state: an all-clear is an absence, not content.
class _AllClear extends StatelessWidget {
  const _AllClear();

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
            Icons.check_circle_outline,
            size: 20,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.vehicleAlertsEmptyBody,
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
