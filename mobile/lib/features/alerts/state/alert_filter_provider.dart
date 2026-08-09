import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ALT-1: the three admin triage tabs, each mapped to the `is_resolved`
/// value `GET /alerts` actually supports. `all` sends no `is_resolved`
/// param at all — the API has no other filter to substitute for it.
enum AlertListTab { pending, resolved, all }

extension AlertListTabX on AlertListTab {
  bool? get isResolved => switch (this) {
    AlertListTab.pending => false,
    AlertListTab.resolved => true,
    AlertListTab.all => null,
  };
}

/// List order. `createdAt` is the only time field `AlertRead` carries, so
/// these two are the whole vocabulary — there is no `resolved_at` to offer
/// a "recently resolved" order from.
enum AlertSortOption { newest, oldest }

/// Feature-local UI state for the alerts list: the triage tab (ALT-1) and
/// the sort order (mirrors `VehicleFilterNotifier`).
class AlertFilterState {
  const AlertFilterState({
    this.tab = AlertListTab.pending,
    this.sort = AlertSortOption.newest,
  });

  final AlertListTab tab;
  final AlertSortOption sort;

  AlertFilterState copyWith({AlertListTab? tab, AlertSortOption? sort}) {
    return AlertFilterState(tab: tab ?? this.tab, sort: sort ?? this.sort);
  }
}

class AlertFilterNotifier extends Notifier<AlertFilterState> {
  @override
  AlertFilterState build() => const AlertFilterState();

  void setTab(AlertListTab tab) => state = state.copyWith(tab: tab);

  void setSort(AlertSortOption sort) => state = state.copyWith(sort: sort);
}

final alertFilterProvider =
    NotifierProvider<AlertFilterNotifier, AlertFilterState>(
      AlertFilterNotifier.new,
    );
