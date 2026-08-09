import 'dart:math' as math;

import '../../domain/rules/fleet_status.dart';
import '../../state/map_markers_provider.dart';

/// Severity rank for picking the loudest status inside a [MarkerCluster] —
/// higher wins. Mirrors the same 5-state vocabulary [statusToneOf] already
/// colors; no new state is introduced.
const _severityRank = {
  FleetStatus.critical: 4,
  FleetStatus.alert: 3,
  FleetStatus.noSignal: 3,
  FleetStatus.active: 2,
  FleetStatus.inactive: 1,
};

/// One rendering group produced by [clusterMarkers]: either a single
/// vehicle or several vehicles close enough, at the current zoom, that
/// their glyphs would visually collide.
class MarkerCluster {
  const MarkerCluster({
    required this.markers,
    required this.latitude,
    required this.longitude,
  });

  final List<VehicleMarker> markers;
  final double latitude;
  final double longitude;

  bool get isSingle => markers.length == 1;

  /// The single worst status among [markers] — used to tint the cluster
  /// badge's ring so a group hides state, not just count.
  FleetStatus get highestSeverity => markers
      .map((m) => m.status)
      .reduce(
        (a, b) => (_severityRank[a] ?? 0) >= (_severityRank[b] ?? 0) ? a : b,
      );
}

/// Groups [markers] into [MarkerCluster]s so vehicles within roughly
/// [pixelThreshold] screen pixels of each other at [zoom] render as one
/// badge instead of overlapping glyphs (map density requirement — many
/// vehicles must not cover too much of the map, and vehicles parked close
/// together must not look like a messy stack of icons).
///
/// ponytail: a fixed lon/lat grid snap, not a proper quad-tree or
/// mercator-corrected distance — good enough for a fleet-sized marker set
/// re-clustered on every zoom change; revisit with a real spatial index
/// only if profiling shows it matters at much larger scale.
List<MarkerCluster> clusterMarkers(
  List<VehicleMarker> markers, {
  required double zoom,
  double pixelThreshold = 42,
}) {
  if (markers.isEmpty) return const [];

  final degreesPerPixel = 360 / (256 * math.pow(2, zoom));
  final cellSize = degreesPerPixel * pixelThreshold;

  final cells = <String, List<VehicleMarker>>{};
  for (final marker in markers) {
    final cellX = (marker.reading.longitude / cellSize).floor();
    final cellY = (marker.reading.latitude / cellSize).floor();
    cells.putIfAbsent('$cellX:$cellY', () => []).add(marker);
  }

  return [
    for (final group in cells.values)
      MarkerCluster(
        markers: group,
        latitude:
            group.map((m) => m.reading.latitude).reduce((a, b) => a + b) /
            group.length,
        longitude:
            group.map((m) => m.reading.longitude).reduce((a, b) => a + b) /
            group.length,
      ),
  ];
}
