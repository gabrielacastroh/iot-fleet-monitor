import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/rules/fleet_status.dart';
import 'package:mobile/features/vehicles/state/vehicle_filter_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts with an empty query and the "all" tab', () {
    final state = container.read(vehicleFilterProvider);

    expect(state.query, isEmpty);
    expect(state.tab, VehicleStatusTab.all);
    expect(state.hasActiveFilters, isFalse);
  });

  test('setQuery updates the search text', () {
    container.read(vehicleFilterProvider.notifier).setQuery('camion');

    expect(container.read(vehicleFilterProvider).query, 'camion');
  });

  test('setTab updates the selected status tab', () {
    container
        .read(vehicleFilterProvider.notifier)
        .setTab(VehicleStatusTab.critical);

    expect(
      container.read(vehicleFilterProvider).tab,
      VehicleStatusTab.critical,
    );
  });

  test('hasActiveFilters is true once a query or a non-"all" tab is set', () {
    final notifier = container.read(vehicleFilterProvider.notifier);

    notifier.setQuery('a');
    expect(container.read(vehicleFilterProvider).hasActiveFilters, isTrue);

    notifier.clear();
    notifier.setTab(VehicleStatusTab.alert);
    expect(container.read(vehicleFilterProvider).hasActiveFilters, isTrue);
  });

  test('clear resets both the query and the tab', () {
    final notifier = container.read(vehicleFilterProvider.notifier);
    notifier
      ..setQuery('camion')
      ..setTab(VehicleStatusTab.critical)
      ..clear();

    final state = container.read(vehicleFilterProvider);
    expect(state.query, isEmpty);
    expect(state.tab, VehicleStatusTab.all);
  });

  test('every non-"all" tab maps to a distinct FleetStatus', () {
    final mapped = VehicleStatusTab.values
        .where((tab) => tab != VehicleStatusTab.all)
        .map((tab) => tab.status)
        .toSet();

    expect(mapped, FleetStatus.values.toSet());
  });
}
