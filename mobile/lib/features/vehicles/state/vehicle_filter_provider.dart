import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/rules/status_filter.dart';

// Re-exported so the list pane keeps importing its filter vocabulary from
// one place, even though the enum itself is now shared with the map.
export '../../../domain/rules/status_filter.dart';

/// The list's sort order. Not a filter — [VehicleFilterState.hasActiveFilters]
/// deliberately ignores it, so "Limpiar filtros" restores the result set
/// without silently reordering what the user is looking at.
enum VehicleSortOption { name, status, recent }

/// Feature-local UI state for the vehicles list: the search text (VEH-2),
/// the selected status tab (VEH-3) and the sort order.
class VehicleFilterState {
  const VehicleFilterState({
    this.query = '',
    this.tab = VehicleStatusTab.all,
    this.sort = VehicleSortOption.name,
  });

  final String query;
  final VehicleStatusTab tab;
  final VehicleSortOption sort;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty || tab != VehicleStatusTab.all;

  VehicleFilterState copyWith({
    String? query,
    VehicleStatusTab? tab,
    VehicleSortOption? sort,
  }) {
    return VehicleFilterState(
      query: query ?? this.query,
      tab: tab ?? this.tab,
      sort: sort ?? this.sort,
    );
  }
}

class VehicleFilterNotifier extends Notifier<VehicleFilterState> {
  @override
  VehicleFilterState build() => const VehicleFilterState();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setTab(VehicleStatusTab tab) => state = state.copyWith(tab: tab);

  void setSort(VehicleSortOption sort) => state = state.copyWith(sort: sort);

  /// Clears the filters only — the chosen sort survives, since reordering
  /// the list was never part of what the user asked to undo.
  void clear() => state = VehicleFilterState(sort: state.sort);
}

final vehicleFilterProvider =
    NotifierProvider<VehicleFilterNotifier, VehicleFilterState>(
      VehicleFilterNotifier.new,
    );
