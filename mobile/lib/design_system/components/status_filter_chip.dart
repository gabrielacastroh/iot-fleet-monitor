import 'package:flutter/material.dart';

import '../../domain/rules/status_filter.dart';
import '../status_tone.dart';
import '../strings/app_strings.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// One status filter chip: a tone dot (or the grid glyph for "Todos"), the
/// state's label, and how many vehicles are behind it — so picking a filter
/// never means tapping into an empty result to find out it was empty.
///
/// Shared by the vehicles list (VEH-3) and the map overlay (MAP-4); both
/// filter the same [VehicleStatusTab] vocabulary, so they render through
/// the same chip rather than two lookalikes that drift.
class StatusFilterChip extends StatelessWidget {
  const StatusFilterChip({
    required this.tab,
    required this.isSelected,
    required this.count,
    required this.onTap,
    super.key,
  });

  final VehicleStatusTab tab;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAll = tab == VehicleStatusTab.all;
    final tone = isAll ? null : statusToneOf(context, tab.status);
    final label = isAll ? AppStrings.vehiclesTabAll : tone!.label;
    final foreground = isSelected
        ? AppColors.primaryForeground
        : AppColors.secondaryForeground;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: Container(
          // A11Y-1: 44dp minimum, and it grows with the text instead of
          // clipping it.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: AppSpacing.sm,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAll)
                Icon(Icons.grid_view_rounded, size: 14, color: foreground)
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    // Keeps the tone dot readable on the selected blue
                    // fill, where the muted grey of `inactive` would
                    // otherwise disappear.
                    color: isSelected ? AppColors.primaryForeground : tone!.dot,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isAll) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$count',
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected
                        ? AppColors.primaryForeground
                        : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
