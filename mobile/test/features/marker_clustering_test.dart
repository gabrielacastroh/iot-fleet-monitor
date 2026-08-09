import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/fleet_status.dart';
import 'package:mobile/features/map/marker_clustering.dart';
import 'package:mobile/state/map_markers_provider.dart';

Device _device(String id) => Device(
  id: id,
  vehicleName: 'V$id',
  deviceCode: 'C$id',
  plate: 'P$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
);

VehicleMarker _marker(
  String id, {
  required double lat,
  required double lng,
  FleetStatus status = FleetStatus.active,
}) => VehicleMarker(
  device: _device(id),
  reading: TelemetryReading(
    id: 't-$id',
    deviceId: id,
    latitude: lat,
    longitude: lng,
    speed: 10,
    fuelLevel: 80,
    temperature: 20,
    recordedAt: DateTime.utc(2026),
  ),
  status: status,
);

void main() {
  test('empty input -> no clusters', () {
    expect(clusterMarkers(const [], zoom: 11), isEmpty);
  });

  test('markers far apart at a normal zoom stay separate', () {
    final markers = [
      _marker('a', lat: -34.60, lng: -58.38),
      _marker('b', lat: -33.00, lng: -60.00),
    ];

    final clusters = clusterMarkers(markers, zoom: 11);

    expect(clusters, hasLength(2));
    expect(clusters.every((c) => c.isSingle), isTrue);
  });

  test('coincident markers collapse into one cluster at any zoom', () {
    final markers = [
      _marker('a', lat: 1, lng: 1),
      _marker('b', lat: 1, lng: 1),
      _marker('c', lat: 1, lng: 1),
    ];

    final clusters = clusterMarkers(markers, zoom: 11);

    expect(clusters, hasLength(1));
    expect(clusters.single.isSingle, isFalse);
    expect(clusters.single.markers, hasLength(3));
    expect(clusters.single.latitude, 1);
    expect(clusters.single.longitude, 1);
  });

  test('zooming in far enough separates previously-clustered markers', () {
    final markers = [
      _marker('a', lat: 1, lng: 1),
      _marker('b', lat: 1.01, lng: 1.01),
    ];

    final zoomedOut = clusterMarkers(markers, zoom: 3);
    final zoomedIn = clusterMarkers(markers, zoom: 18);

    expect(zoomedOut, hasLength(1));
    expect(zoomedIn, hasLength(2));
  });

  test('highestSeverity picks critical over alert/noSignal over active', () {
    final cluster = MarkerCluster(
      markers: [
        _marker('a', lat: 1, lng: 1, status: FleetStatus.active),
        _marker('b', lat: 1, lng: 1, status: FleetStatus.alert),
        _marker('c', lat: 1, lng: 1, status: FleetStatus.critical),
      ],
      latitude: 1,
      longitude: 1,
    );

    expect(cluster.highestSeverity, FleetStatus.critical);
  });
}
