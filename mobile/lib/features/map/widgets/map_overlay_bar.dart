import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/status_filter_chip.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_shadows.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../state/map_filter_provider.dart';
import 'map_filters_sheet.dart';

/// MAP-4's floating overlay: the vehicle/plate/device search, the filters
/// entry point, and the quick status chips — a layer over the map rather
/// than a header above it, so the map keeps the full viewport.
///
/// The chip strip only carries the states worth one tap ("Todos" plus the
/// three that mean something is happening); `Inactivo` and `Crítico` live
/// behind the filters button, which is what stops the strip from becoming
/// a six-chip scroll over the map.
class MapOverlayBar extends ConsumerStatefulWidget {
  const MapOverlayBar({super.key});

  static const quickTabs = [
    VehicleStatusTab.all,
    VehicleStatusTab.active,
    VehicleStatusTab.alert,
    VehicleStatusTab.noSignal,
  ];

  /// Wide viewports get the overlay as a panel, not a full-bleed bar — a
  /// search field the width of a tablet reads as a page header.
  static const maxWidth = 560.0;

  @override
  ConsumerState<MapOverlayBar> createState() => _MapOverlayBarState();
}

class _MapOverlayBarState extends ConsumerState<MapOverlayBar> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Limpiar filtros" lives in the filters sheet, which can't reach this
    // field's controller — without this the query would keep showing in the
    // box after the filter behind it was already cleared.
    ref.listen(mapFilterProvider.select((filter) => filter.query), (_, query) {
      if (query.isEmpty && _controller.text.isNotEmpty) _controller.clear();
    });

    final filter = ref.watch(mapFilterProvider);
    final countByTab = ref.watch(mapMarkerCountByTabProvider);
    // A state picked from the filters sheet still has to be visible and
    // deselectable, so it joins the strip instead of silently applying.
    final tabs = MapOverlayBar.quickTabs.contains(filter.tab)
        ? MapOverlayBar.quickTabs
        : [...MapOverlayBar.quickTabs, filter.tab];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MapOverlayBar.maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Expanded(child: _SearchField(controller: _controller)),
                  const SizedBox(width: AppSpacing.md),
                  _FiltersButton(isActive: filter.hasActiveFilters),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  for (final (index, tab) in tabs.indexed) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.sm),
                    StatusFilterChip(
                      // Stable handle for tests: the visible label alone is
                      // ambiguous, since a marker sheet's status pill
                      // carries the same word.
                      key: ValueKey('map_filter_chip_${tab.name}'),
                      tab: tab,
                      isSelected: tab == filter.tab,
                      count: countByTab[tab] ?? 0,
                      onTap: () =>
                          ref.read(mapFilterProvider.notifier).setTab(tab),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.lift,
      ),
      child: Semantics(
        textField: true,
        label: AppStrings.mapSearchLabel,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.mapSearchHint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedForeground,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppColors.mutedForeground,
            ),
            // Listens to the controller rather than the parent's rebuilds:
            // the clear affordance has to appear on the first keystroke, and
            // the overlay above only rebuilds when the filter state changes.
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.mutedForeground,
                      tooltip: AppStrings.vehiclesClearFiltersLabel,
                      onPressed: () {
                        controller.clear();
                        ref.read(mapFilterProvider.notifier).setQuery('');
                      },
                    ),
            ),
            filled: true,
            fillColor: AppColors.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md + 2,
              horizontal: AppSpacing.md,
            ),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            focusedBorder: _border(AppColors.primary, width: 1.5),
          ),
          onChanged: (value) =>
              ref.read(mapFilterProvider.notifier).setQuery(value),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.mapFiltersLabel,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: AppShadows.lift,
          ),
          child: Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              onTap: () => showMapFiltersSheet(context),
              child: SizedBox(
                // A11Y-1: square 52dp target, matching the field's height.
                width: 52,
                height: 52,
                child: Icon(
                  Icons.filter_alt_outlined,
                  size: 22,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
