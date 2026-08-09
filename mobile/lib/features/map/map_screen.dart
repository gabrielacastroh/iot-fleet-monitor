import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../design_system/components/app_empty_state.dart';
import '../../design_system/components/async_state_view.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_shadows.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../domain/models/device.dart';
import '../../router/routes.dart';
import '../../state/devices_provider.dart';
import '../../state/map_markers_provider.dart';
import 'marker_clustering.dart';
import 'state/map_filter_provider.dart';
import 'widgets/map_controls.dart';
import 'widgets/map_overlay_bar.dart';
import 'widgets/map_vehicle_sheet.dart';
import 'widgets/vehicle_marker.dart';

/// MAP-1..MAP-4: one marker per device with a reading, live-patched via
/// WS-6 through [mapMarkersProvider] (no polling, no simulation logic —
/// positions only ever change because [latestTelemetryProvider] does).
/// [devicesProvider] gates the four-state contract (design §9), the same
/// pattern this screen's siblings use. Markers that would collide on screen
/// at the current zoom render as a single [VehicleClusterMarker] instead of
/// stacking (`marker_clustering.dart`).
///
/// Everything above the tiles is a floating layer — search and status
/// filters at the top, controls on the right, the selected vehicle's sheet
/// at the bottom — so the map keeps the whole viewport and the bottom
/// navigation stays the app's only chrome.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _defaultCenter = LatLng(-34.6037, -58.3816); // Buenos Aires
  static const _defaultZoom = 11.0;
  static const _fleetFitPadding = EdgeInsets.all(72);

  /// Close enough to read a street, far enough not to lose the
  /// surroundings — where the map lands when a search narrows to one
  /// vehicle from a city-wide view.
  static const _singleMatchZoom = 14.0;

  final _mapController = MapController();
  double _zoom = _defaultZoom;

  /// The selection is held by id, not by value: markers are rebuilt on
  /// every WS-6 patch, so keeping the object would freeze the sheet on the
  /// reading that was current when it opened.
  String? _selectedDeviceId;
  bool _sheetExpanded = false;

  /// Which vehicle the search already flew to. Without it, every WS-6
  /// patch while a one-match query is typed would yank the camera back and
  /// undo whatever the user panned to in between.
  String? _autoFocusedDeviceId;

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // Re-cluster only on an actual zoom change, not on every pan pixel.
    if ((camera.zoom - _zoom).abs() < 0.05) return;
    setState(() => _zoom = camera.zoom);
  }

  /// MAP-4: typing until exactly one vehicle is left is a way of asking
  /// "where is this one?" — so the map goes there and opens its sheet
  /// instead of leaving a lone marker somewhere off screen. Collapsed, so
  /// the card doesn't cover the map while the keyboard is still up.
  void _focusSingleMatch(List<VehicleMarker> markers) {
    final hasQuery = ref.read(mapFilterProvider).query.trim().isNotEmpty;
    if (!hasQuery || markers.length != 1) {
      _autoFocusedDeviceId = null;
      return;
    }

    final marker = markers.single;
    if (marker.device.id == _autoFocusedDeviceId) return;
    _autoFocusedDeviceId = marker.device.id;

    setState(() {
      _selectedDeviceId = marker.device.id;
      _sheetExpanded = false;
    });
    _mapController.move(
      LatLng(marker.reading.latitude, marker.reading.longitude),
      _mapController.camera.zoom < _singleMatchZoom
          ? _singleMatchZoom
          : _mapController.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visibleMapMarkersProvider, (_, markers) {
      _focusSingleMatch(markers);
    });

    final devicesAsync = ref.watch(devicesProvider);
    final allMarkers = ref.watch(mapMarkersProvider);
    final markers = ref.watch(visibleMapMarkersProvider);
    final clusters = clusterMarkers(markers, zoom: _zoom);
    final selected = _selectedMarker(markers);

    return AsyncStateView<List<Device>>(
      state: devicesAsync,
      // The four-state contract still answers "does this fleet have
      // anything to show", never "did the current filter match" — a filter
      // that excludes everything is a result, not an empty screen.
      isEmpty: (_) => allMarkers.isEmpty,
      data: (_, _) => Stack(
        children: [
          Positioned.fill(child: _map(clusters)),
          Positioned.fill(
            child: SafeArea(
              child: Stack(
                children: [
                  const MapOverlayBar(),
                  Positioned(
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: MapControls(
                      onRecenter: _recenterOnFleet,
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                    ),
                  ),
                  if (markers.isEmpty) const _NoMatchesBanner(),
                  if (selected != null)
                    MapVehicleSheet(
                      marker: selected,
                      isExpanded: _sheetExpanded,
                      onToggle: () =>
                          setState(() => _sheetExpanded = !_sheetExpanded),
                      onDismiss: _clearSelection,
                      onOpenDetail: () => context.push(
                        Routes.vehicleDetail(selected.device.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      empty: const AppEmptyState(
        icon: Icons.location_off,
        title: AppStrings.mapEmptyTitle,
        body: AppStrings.mapEmptyBody,
      ),
      onRetry: () => ref.invalidate(devicesProvider),
    );
  }

  Widget _map(List<MarkerCluster> clusters) {
    final markers = ref.read(visibleMapMarkersProvider);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: markers.isNotEmpty
            ? LatLng(
                markers.first.reading.latitude,
                markers.first.reading.longitude,
              )
            : _defaultCenter,
        initialZoom: _defaultZoom,
        onPositionChanged: _onPositionChanged,
        // Tapping the map is how you put the sheet away without hunting
        // for a close button.
        onTap: (_, _) => _clearSelection(),
      ),
      children: [
        TileLayer(
          urlTemplate: osmTileUrlTemplate,
          userAgentPackageName: osmUserAgentPackageName,
        ),
        MarkerLayer(
          markers: [
            for (final cluster in clusters)
              Marker(
                point: LatLng(cluster.latitude, cluster.longitude),
                width: VehicleMarkerIcon.touchTarget,
                height: VehicleMarkerIcon.touchTarget,
                child: cluster.isSingle
                    ? VehicleMarkerIcon(
                        status: cluster.markers.single.status,
                        vehicleName: cluster.markers.single.device.vehicleName,
                        isSelected:
                            cluster.markers.single.device.id ==
                            _selectedDeviceId,
                        onTap: () => _selectMarker(cluster.markers.single),
                      )
                    : VehicleClusterMarker(
                        cluster: cluster,
                        onTap: () => _zoomIntoCluster(cluster),
                      ),
              ),
          ],
        ),
      ],
    );
  }

  VehicleMarker? _selectedMarker(List<VehicleMarker> markers) {
    final id = _selectedDeviceId;
    if (id == null) return null;
    for (final marker in markers) {
      if (marker.device.id == id) return marker;
    }
    // The selected vehicle was filtered out (or stopped reporting): drop
    // the sheet rather than leave a stale card over the map.
    return null;
  }

  void _selectMarker(VehicleMarker marker) {
    setState(() {
      _selectedDeviceId = marker.device.id;
      _sheetExpanded = true;
    });
    _mapController.move(
      LatLng(marker.reading.latitude, marker.reading.longitude),
      _mapController.camera.zoom,
    );
  }

  void _clearSelection() {
    if (_selectedDeviceId == null) return;
    setState(() {
      _selectedDeviceId = null;
      _sheetExpanded = false;
    });
  }

  void _zoomIntoCluster(MarkerCluster cluster) {
    _mapController.move(LatLng(cluster.latitude, cluster.longitude), _zoom + 2);
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  /// "Recentre" means the visible fleet — this app has no location
  /// permission, so there is no device position to return to.
  void _recenterOnFleet() {
    final markers = ref.read(visibleMapMarkersProvider);
    if (markers.isEmpty) return;

    final points = [
      for (final marker in markers)
        LatLng(marker.reading.latitude, marker.reading.longitude),
    ];
    if (points.length == 1) {
      _mapController.move(points.single, _defaultZoom);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(coordinates: points, padding: _fleetFitPadding),
    );
  }
}

/// Shown when the filters exclude every vehicle: the map stays where it is,
/// with one compact line saying why nothing is on it.
class _NoMatchesBanner extends ConsumerWidget {
  const _NoMatchesBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.xl),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          boxShadow: AppShadows.lift,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 18,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                AppStrings.vehiclesNoMatchesTitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: () => ref.read(mapFilterProvider.notifier).clear(),
              child: const Text(AppStrings.vehiclesClearFiltersLabel),
            ),
          ],
        ),
      ),
    );
  }
}
