import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/status_filter_chip.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../state/map_filter_provider.dart';

/// The full status vocabulary behind the overlay's filters button — the
/// same [VehicleStatusTab] set the vehicles list offers, including the two
/// states the quick strip leaves out. Selecting one closes the sheet, so
/// the result is visible on the map immediately.
Future<void> showMapFiltersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
    ),
    builder: (context) => const _MapFiltersSheet(),
  );
}

class _MapFiltersSheet extends ConsumerWidget {
  const _MapFiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(mapFilterProvider);
    final countByTab = ref.watch(mapMarkerCountByTabProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.mapFiltersSheetTitle,
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tab in VehicleStatusTab.values)
                  StatusFilterChip(
                    key: ValueKey('map_filters_sheet_chip_${tab.name}'),
                    tab: tab,
                    isSelected: tab == filter.tab,
                    count: countByTab[tab] ?? 0,
                    onTap: () {
                      ref.read(mapFilterProvider.notifier).setTab(tab);
                      Navigator.of(context).maybePop();
                    },
                  ),
              ],
            ),
            if (filter.hasActiveFilters) ...[
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(mapFilterProvider.notifier).clear();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text(AppStrings.vehiclesClearFiltersLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
