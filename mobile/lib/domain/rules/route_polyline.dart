import 'package:latlong2/latlong.dart';

import '../models/telemetry_reading.dart';

/// VDET-5: builds a `(latitude, longitude)` polyline from a telemetry
/// history fetch, ordered chronologically oldest -> newest regardless of
/// the order the API/cache returned it in.
List<LatLng> routePolyline(List<TelemetryReading> readings) {
  final sorted = [...readings]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  return [
    for (final reading in sorted) LatLng(reading.latitude, reading.longitude),
  ];
}
