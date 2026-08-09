import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/alert_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/telemetry_repository.dart';
import 'api_providers.dart';
import 'cache_providers.dart';

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(authApiProvider)),
);

/// Resolves the user's [FleetCache] first — the box open is async — before
/// constructing the repository around it. Throws if watched without an
/// open session (every consumer lives inside the authenticated shell).
final deviceRepositoryProvider = FutureProvider<DeviceRepository>((ref) async {
  final cache = await ref.watch(fleetCacheProvider.future);
  if (cache == null) {
    throw StateError('deviceRepositoryProvider requires an open session.');
  }
  return DeviceRepository(ref.watch(devicesApiProvider), cache);
});

final telemetryRepositoryProvider = FutureProvider<TelemetryRepository>((
  ref,
) async {
  final cache = await ref.watch(fleetCacheProvider.future);
  if (cache == null) {
    throw StateError('telemetryRepositoryProvider requires an open session.');
  }
  return TelemetryRepository(ref.watch(telemetryApiProvider), cache);
});

/// Only ever watched from an admin session — see [AlertsNotifier]'s
/// ROLE-2 note for why that gate lives at the call site, not here.
final alertRepositoryProvider = FutureProvider<AlertRepository>((ref) async {
  final cache = await ref.watch(fleetCacheProvider.future);
  if (cache == null) {
    throw StateError('alertRepositoryProvider requires an open session.');
  }
  return AlertRepository(ref.watch(alertsApiProvider), cache);
});
