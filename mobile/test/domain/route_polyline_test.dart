import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/route_polyline.dart';

TelemetryReading _reading({
  required String id,
  required DateTime recordedAt,
  required double lat,
  required double lng,
}) => TelemetryReading(
  id: id,
  deviceId: 'd1',
  latitude: lat,
  longitude: lng,
  speed: 0,
  fuelLevel: 0,
  temperature: 0,
  recordedAt: recordedAt,
);

void main() {
  test('VDET-5: an unordered fixture is sorted oldest -> newest', () {
    final readings = [
      _reading(
        id: 't2',
        recordedAt: DateTime.utc(2026, 1, 1, 12),
        lat: 2,
        lng: 2,
      ),
      _reading(
        id: 't1',
        recordedAt: DateTime.utc(2026, 1, 1, 10),
        lat: 1,
        lng: 1,
      ),
      _reading(
        id: 't3',
        recordedAt: DateTime.utc(2026, 1, 1, 14),
        lat: 3,
        lng: 3,
      ),
    ];

    final points = routePolyline(readings);

    expect(points, [
      const LatLng(1, 1),
      const LatLng(2, 2),
      const LatLng(3, 3),
    ]);
  });

  test('VDET-5: a reverse-ordered fixture is sorted oldest -> newest', () {
    final readings = [
      _reading(
        id: 't3',
        recordedAt: DateTime.utc(2026, 1, 1, 14),
        lat: 3,
        lng: 3,
      ),
      _reading(
        id: 't2',
        recordedAt: DateTime.utc(2026, 1, 1, 12),
        lat: 2,
        lng: 2,
      ),
      _reading(
        id: 't1',
        recordedAt: DateTime.utc(2026, 1, 1, 10),
        lat: 1,
        lng: 1,
      ),
    ];

    final points = routePolyline(readings);

    expect(points, [
      const LatLng(1, 1),
      const LatLng(2, 2),
      const LatLng(3, 3),
    ]);
  });

  test('an empty history produces an empty polyline', () {
    expect(routePolyline(const []), isEmpty);
  });
}
