import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/app_empty_state.dart';
import '../../../design_system/components/async_state_view.dart';
import '../../../design_system/components/status_filter_chip.dart';
import '../../../design_system/components/vehicle_card.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/device.dart';
import '../../../domain/models/telemetry_reading.dart';
import '../../../domain/rules/derived_alerts.dart';
import '../../../domain/rules/device_search.dart';
import '../../../domain/rules/fleet_status.dart';
import '../../../state/devices_provider.dart';
import '../../../state/telemetry_provider.dart';
import '../state/vehicle_filter_provider.dart';

/// VEH-1..VEH-8's list body — title, search field, status filter chips, the
/// count/sort toolbar and the device list itself — factored out of
/// [VehiclesScreen] so it can also be reused as the companion pane
/// [VehicleDetailScreen] renders at ≥600dp (RESP-1, design §14 risk #3's
/// `LayoutBuilder` fallback: the route tree stays the same, each screen just
/// decides locally whether to show a second pane).
class VehiclesListPane extends ConsumerStatefulWidget {
  const VehiclesListPane({required this.onSelectDevice, super.key});

  final void Function(Device device) onSelectDevice;

  @override
  ConsumerState<VehiclesListPane> createState() => _VehiclesListPaneState();
}

class _VehiclesListPaneState extends ConsumerState<VehiclesListPane> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    ref.read(vehicleFilterProvider.notifier).clear();
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final telemetryAsync = ref.watch(latestTelemetryProvider);
    final filter = ref.watch(vehicleFilterProvider);
    final telemetryByDevice = telemetryAsync.valueOrNull?.value ?? const {};
    final devices = devicesAsync.valueOrNull?.value ?? const <Device>[];
    final fleetIsEmpty = devicesAsync.valueOrNull?.value.isEmpty ?? false;

    // Counts come from the search-matched set, not the whole fleet: with a
    // query typed, "Activos 3" has to mean three of the vehicles you can
    // currently see, or the chip contradicts the list under it.
    final searchMatched = _searchMatches(devices, telemetryByDevice, filter);
    final countByTab = _countByTab(searchMatched);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.vehiclesTitle,
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.vehiclesSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppStrings.vehiclesSearchHint,
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md + 2,
                    horizontal: AppSpacing.md,
                  ),
                  border: _searchBorder(AppColors.border),
                  enabledBorder: _searchBorder(AppColors.border),
                  focusedBorder: _searchBorder(AppColors.primary, width: 1.5),
                ),
                onChanged: (value) =>
                    ref.read(vehicleFilterProvider.notifier).setQuery(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _StatusFilterChips(
          selected: filter.tab,
          countByTab: countByTab,
          onSelect: (tab) =>
              ref.read(vehicleFilterProvider.notifier).setTab(tab),
        ),
        _ListToolbar(
          count: countByTab[filter.tab] ?? 0,
          sort: filter.sort,
          onSort: (sort) =>
              ref.read(vehicleFilterProvider.notifier).setSort(sort),
        ),
        Expanded(
          child: AsyncStateView<List<Device>>(
            state: devicesAsync,
            isEmpty: (loaded) =>
                _visibleEntries(loaded, telemetryByDevice, filter).isEmpty,
            data: (loaded, cachedAt) {
              final entries = _visibleEntries(
                loaded,
                telemetryByDevice,
                filter,
              );
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: VehicleCard(
                      device: entry.device,
                      status: entry.status,
                      latestReading: entry.reading,
                      onTap: () => widget.onSelectDevice(entry.device),
                    ),
                  );
                },
              );
            },
            empty: fleetIsEmpty
                ? const AppEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: AppStrings.vehiclesEmptyFleetTitle,
                    body: AppStrings.vehiclesEmptyFleetBody,
                  )
                : AppEmptyState(
                    icon: Icons.search_off,
                    title: AppStrings.vehiclesNoMatchesTitle,
                    body: AppStrings.vehiclesNoMatchesBody,
                    action: OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text(AppStrings.vehiclesClearFiltersLabel),
                    ),
                  ),
            onRetry: () => ref.invalidate(devicesProvider),
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _searchBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.xl),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// VEH-3's status filter, as a scrolling chip strip. Each chip carries its
/// own tone dot and the number of matches behind it, so picking a filter
/// never means tapping into an empty list to find out it was empty.
class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.selected,
    required this.countByTab,
    required this.onSelect,
  });

  final VehicleStatusTab selected;
  final Map<VehicleStatusTab, int> countByTab;
  final ValueChanged<VehicleStatusTab> onSelect;

  @override
  Widget build(BuildContext context) {
    // A `SingleChildScrollView`, not a horizontal `ListView`: the strip has
    // six fixed children, so lazy building buys nothing, and a `ListView`
    // needs a fixed height — which clipped the chips at 2.0x text scale
    // (A11Y-3). A `Row` sizes to its content instead.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final (index, tab) in VehicleStatusTab.values.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            StatusFilterChip(
              // Stable handle for tests: the visible label alone is
              // ambiguous, since a matching vehicle's status pill carries
              // the same word.
              key: ValueKey('vehicle_filter_chip_${tab.name}'),
              tab: tab,
              isSelected: tab == selected,
              count: countByTab[tab] ?? 0,
              onTap: () => onSelect(tab),
            ),
          ],
        ],
      ),
    );
  }
}

/// How many rows are below, and the order they are in.
class _ListToolbar extends StatelessWidget {
  const _ListToolbar({
    required this.count,
    required this.sort,
    required this.onSort,
  });

  final int count;
  final VehicleSortOption sort;
  final ValueChanged<VehicleSortOption> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.vehiclesCountLabel(count),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          // A11Y-3: flexible, so at 2.0x text scale the sort control gives
          // ground instead of pushing the row 52px past its edge.
          Flexible(
            child: PopupMenuButton<VehicleSortOption>(
              initialValue: sort,
              onSelected: onSort,
              tooltip: AppStrings.vehiclesSortLabel,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => [
                for (final option in VehicleSortOption.values)
                  PopupMenuItem(value: option, child: Text(_sortLabel(option))),
              ],
              child: Container(
                // A11Y-1: the label alone was a 34dp-tall tap target.
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '${AppStrings.vehiclesSortLabel}: ',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _sortLabel(sort),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sortLabel(VehicleSortOption option) => switch (option) {
  VehicleSortOption.name => AppStrings.vehiclesSortByName,
  VehicleSortOption.status => AppStrings.vehiclesSortByStatus,
  VehicleSortOption.recent => AppStrings.vehiclesSortByRecent,
};

class _VehicleEntry {
  const _VehicleEntry({
    required this.device,
    required this.status,
    this.reading,
  });

  final Device device;
  final FleetStatus status;
  final TelemetryReading? reading;
}

/// VEH-2 (case-insensitive substring search) applied over VEH-1's merged
/// device/telemetry set. Split out from the tab filter so the chip counts
/// can be taken from this stage — the tab can't narrow the numbers that
/// describe the tabs themselves.
List<_VehicleEntry> _searchMatches(
  List<Device> devices,
  Map<String, TelemetryReading> telemetryByDevice,
  VehicleFilterState filter,
) {
  final entries = <_VehicleEntry>[];

  for (final device in devices) {
    if (!deviceMatchesQuery(device, filter.query)) continue;

    final reading = telemetryByDevice[device.id];
    entries.add(
      _VehicleEntry(
        device: device,
        status: fleetOverlayStatus(device, reading),
        reading: reading,
      ),
    );
  }

  return entries;
}

Map<VehicleStatusTab, int> _countByTab(List<_VehicleEntry> entries) {
  return {
    for (final tab in VehicleStatusTab.values)
      tab: tab == VehicleStatusTab.all
          ? entries.length
          : entries.where((entry) => entry.status == tab.status).length,
  };
}

/// Search (VEH-2) + status tab (VEH-3) + the chosen sort order.
List<_VehicleEntry> _visibleEntries(
  List<Device> devices,
  Map<String, TelemetryReading> telemetryByDevice,
  VehicleFilterState filter,
) {
  final entries = _searchMatches(devices, telemetryByDevice, filter)
      .where(
        (entry) =>
            filter.tab == VehicleStatusTab.all ||
            entry.status == filter.tab.status,
      )
      .toList();

  entries.sort(switch (filter.sort) {
    VehicleSortOption.name => _byName,
    VehicleSortOption.status => _bySeverityThenName,
    VehicleSortOption.recent => _byMostRecentReading,
  });
  return entries;
}

int _byName(_VehicleEntry a, _VehicleEntry b) => foldDiacritics(
  a.device.vehicleName.toLowerCase(),
).compareTo(foldDiacritics(b.device.vehicleName.toLowerCase()));

/// Worst first — the point of sorting by status is to surface what needs
/// attention, not to group alphabetically by state name.
int _bySeverityThenName(_VehicleEntry a, _VehicleEntry b) {
  final bySeverity = _severity(b.status).compareTo(_severity(a.status));
  return bySeverity != 0 ? bySeverity : _byName(a, b);
}

int _severity(FleetStatus status) => switch (status) {
  FleetStatus.critical => 4,
  FleetStatus.alert => 3,
  FleetStatus.noSignal => 2,
  FleetStatus.inactive => 1,
  FleetStatus.active => 0,
};

/// Devices that have never reported sort last: "no reading" is not the
/// oldest reading, it is the absence of one.
int _byMostRecentReading(_VehicleEntry a, _VehicleEntry b) {
  final aAt = a.reading?.recordedAt;
  final bAt = b.reading?.recordedAt;
  if (aAt == null && bAt == null) return _byName(a, b);
  if (aAt == null) return 1;
  if (bAt == null) return -1;
  return bAt.compareTo(aAt);
}
