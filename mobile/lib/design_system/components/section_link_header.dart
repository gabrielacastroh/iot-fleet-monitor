import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A titled section heading with an optional link action on the right —
/// the dashboard's sections and the vehicle detail's "Alertas activas".
///
/// Deliberately not the shared [SectionHeader], which renders a quiet muted
/// eyebrow. On these screens the sections separate full card surfaces
/// rather than bare lists, so the heading has to hold its own weight
/// against them — changing the eyebrow would have restyled the vehicles,
/// map and alerts screens along with it.
class SectionLinkHeader extends StatelessWidget {
  const SectionLinkHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;

    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.titleMedium)),
        if (label != null && onAction != null)
          // A11Y-3: flexible, so a long action label at 2.0x text scale
          // shrinks with the row instead of pushing past its edge.
          Flexible(
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Padding(
                // Keeps the label optically flush with the card edge below
                // while still giving the tap target room around the text.
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
