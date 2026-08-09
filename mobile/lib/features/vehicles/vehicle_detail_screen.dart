import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/app_empty_state.dart';
import '../../design_system/components/status_badge.dart';
import '../../design_system/components/two_pane_row.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../domain/models/device.dart';
import '../../domain/rules/derived_alerts.dart';
import '../../domain/rules/fleet_status.dart';
import '../../router/routes.dart';
import '../../state/devices_provider.dart';
import '../../state/session_provider.dart';
import '../../state/telemetry_provider.dart';
import 'widgets/active_alerts_section.dart';
import 'widgets/telemetry_section.dart';
import 'widgets/vehicle_hero_card.dart';
import 'widgets/vehicles_list_pane.dart';

/// VDET-1..VDET-7: the vehicle detail at `/vehicles/:deviceId`. [device] is
/// resolved from the already-loaded `devicesProvider` list (VEH-1) — no
/// separate network fetch for the screen itself.
///
/// One scrolling page rather than the previous three tabs: current state,
/// history and open alerts are read together when triaging a vehicle, and
/// tabs hid two thirds of that behind a tap. Each block still owns its own
/// data and its own four states, so nothing here gates the whole screen on
/// telemetry or alerts loading.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.deviceId, super.key});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider).valueOrNull?.value ?? const [];
    final device = _findById(devices, deviceId);

    if (device == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const AppEmptyState(
          icon: Icons.search_off,
          title: AppStrings.vehicleNotFoundTitle,
          body: AppStrings.vehicleNotFoundBody,
        ),
      );
    }

    final reading = ref
        .watch(latestTelemetryProvider)
        .valueOrNull
        ?.value[device.id];
    final status = fleetOverlayStatus(device, reading);
    final detail = _DetailBody(device: device, status: status);

    return Scaffold(
      appBar: _DetailAppBar(device: device, status: status),
      // RESP-1: at ≥600dp this screen also renders as the tablet companion
      // pane on the right, with the same vehicles list on the left —
      // selecting a different vehicle here replaces the current detail
      // route (`pushReplacement`) instead of stacking a new one.
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < tabletBreakpoint) return detail;
          return twoPaneRow(
            list: VehiclesListPane(
              onSelectDevice: (selected) =>
                  context.pushReplacement(Routes.vehicleDetail(selected.id)),
            ),
            detail: detail,
          );
        },
      ),
    );
  }

  Device? _findById(List<Device> devices, String id) {
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }
}

/// Name, plate/`device_code` and the live status pill. The code is opaque —
/// rendered as the server sent it, never parsed (design §4).
class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailAppBar({required this.device, required this.status});

  final Device device;
  final FleetStatus status;

  static const _height = 72.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _height,
      titleSpacing: 0,
      title: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              device.vehicleName,
              style: AppTypography.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${device.plate} · ${device.deviceCode}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Center(child: StatusPill(status: status, showDot: true)),
        ),
      ],
    );
  }
}

/// The scrolling page. Constrained on wide viewports so the charts don't
/// stretch into unreadably flat lines on a tablet's detail pane.
class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.device, required this.status});

  final Device device;
  final FleetStatus status;

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref
        .watch(latestTelemetryProvider)
        .valueOrNull
        ?.value[device.id];
    final isAdmin = ref.watch(isAdminProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            VehicleHeroCard(
              device: device,
              status: status,
              reading: reading,
            ),
            const SizedBox(height: AppSpacing.xxl),
            TelemetrySection(deviceId: device.id),
            // ROLE-2: a non-admin has no `/alerts` access at all, so the
            // section is absent rather than shown locked — there is
            // nothing behind it for them to unlock.
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.xxl),
              ActiveAlertsSection(deviceId: device.id),
            ],
          ],
        ),
      ),
    );
  }
}
