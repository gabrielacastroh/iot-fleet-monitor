import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/config/map_config.dart';
import '../../../design_system/components/app_empty_state.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../domain/rules/route_polyline.dart';

/// VDET-5: the fetched history's route as a polyline over OSM tiles,
/// ordered oldest -> newest by [routePolyline]. Renders the VDET-6 empty
/// copy when there are no positions to draw instead of an empty map.
class RouteMap extends StatelessWidget {
  const RouteMap({required this.readings, super.key});

  final List<TelemetryReading> readings;

  @override
  Widget build(BuildContext context) {
    final points = routePolyline(readings);
    if (points.isEmpty) {
      return const AppEmptyState(
        icon: Icons.map_outlined,
        title: AppStrings.routeMapTitle,
        body: AppStrings.routeMapEmptyBody,
      );
    }

    return SizedBox(
      height: 240,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: points.last, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: osmTileUrlTemplate,
              userAgentPackageName: osmUserAgentPackageName,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
