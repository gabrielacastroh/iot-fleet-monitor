import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/rules/device_search.dart';
import '../../../domain/rules/status_filter.dart';
import '../../../state/map_markers_provider.dart';

export '../../../domain/rules/status_filter.dart';

/// MAP-4: the map overlay's search text and status filter. Feature-local
/// and deliberately separate from the vehicles list's own filter state —
/// the two screens are looked at side by side, and typing a plate on the
/// map must not silently re-filter the list behind it.
class MapFilterState {
  const MapFilterState({this.query = '', this.tab = VehicleStatusTab.all});

  final String query;
  final VehicleStatusTab tab;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty || tab != VehicleStatusTab.all;

  MapFilterState copyWith({String? query, VehicleStatusTab? tab}) =>
      MapFilterState(query: query ?? this.query, tab: tab ?? this.tab);
}

class MapFilterNotifier extends Notifier<MapFilterState> {
  @override
  MapFilterState build() => const MapFilterState();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setTab(VehicleStatusTab tab) => state = state.copyWith(tab: tab);

  void clear() => state = const MapFilterState();
}

final mapFilterProvider =
    NotifierProvider<MapFilterNotifier, MapFilterState>(MapFilterNotifier.new);

/// The markers left after the search term, before the status tab narrows
/// them further. The chip counts are taken from here: with a query typed,
/// "Activos 3" has to mean three of the vehicles currently findable, or the
/// chip contradicts the map under it (same rule as the vehicles list).
final searchedMapMarkersProvider = Provider<List<VehicleMarker>>((ref) {
  final markers = ref.watch(mapMarkersProvider);
  final query = ref.watch(mapFilterProvider).query;

  return [
    for (final marker in markers)
      if (deviceMatchesQuery(marker.device, query)) marker,
  ];
});

/// What the map actually draws: search + status tab.
final visibleMapMarkersProvider = Provider<List<VehicleMarker>>((ref) {
  final markers = ref.watch(searchedMapMarkersProvider);
  final tab = ref.watch(mapFilterProvider).tab;
  if (tab == VehicleStatusTab.all) return markers;

  return [
    for (final marker in markers)
      if (marker.status == tab.status) marker,
  ];
});

/// How many searched markers each chip stands for.
final mapMarkerCountByTabProvider = Provider<Map<VehicleStatusTab, int>>((ref) {
  final markers = ref.watch(searchedMapMarkersProvider);

  return {
    for (final tab in VehicleStatusTab.values)
      tab: tab == VehicleStatusTab.all
          ? markers.length
          : markers.where((marker) => marker.status == tab.status).length,
  };
});
