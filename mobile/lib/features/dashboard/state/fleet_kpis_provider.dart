import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/rules/fleet_kpis.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/devices_provider.dart';
import '../../../state/session_provider.dart';
import '../../../state/telemetry_provider.dart';

/// DASH-1: composes existing async providers into the dashboard KPI
/// aggregate — never fetches anything itself. The
/// `if (ref.watch(isAdminProvider))` branch below IS the ROLE-2 enforcement
/// for the dashboard: Riverpod only ever *constructs* `alertsProvider`
/// (and therefore only ever fires `GET /alerts`) inside that branch, so a
/// non-admin session can't reach it from here regardless of what the KPI
/// row widget does with the result.
final fleetKpisProvider = Provider<FleetKpis>((ref) {
  final devices = ref.watch(devicesProvider).valueOrNull?.value ?? const [];
  final latestByDevice =
      ref.watch(latestTelemetryProvider).valueOrNull?.value ?? const {};

  int? openAlertsCount;
  if (ref.watch(isAdminProvider)) {
    openAlertsCount = ref.watch(alertsProvider).valueOrNull?.value.length;
  }

  return computeFleetKpis(
    devices: devices,
    latestByDevice: latestByDevice,
    openAlertsCount: openAlertsCount,
  );
});
