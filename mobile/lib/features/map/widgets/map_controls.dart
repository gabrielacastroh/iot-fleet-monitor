import 'package:flutter/material.dart';

import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_shadows.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// The map's floating controls: recentre, then zoom in/out as one stacked
/// pair. Compact and out of the way on the right edge, above whatever the
/// sheet is occupying.
///
/// "Recentre" means the fleet, not the phone: this app has no location
/// permission and no geolocation dependency, so a control that claimed to
/// find the user would have nothing behind it.
class MapControls extends StatelessWidget {
  const MapControls({
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    super.key,
  });

  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ControlSurface(
          children: [
            _ControlButton(
              icon: Icons.my_location,
              label: AppStrings.mapRecenterLabel,
              onTap: onRecenter,
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ControlSurface(
          children: [
            _ControlButton(
              icon: Icons.add,
              label: AppStrings.mapZoomInLabel,
              onTap: onZoomIn,
            ),
            const Divider(
              height: 1,
              thickness: 1,
              indent: AppSpacing.sm,
              endIndent: AppSpacing.sm,
              color: AppColors.border,
            ),
            _ControlButton(
              icon: Icons.remove,
              label: AppStrings.mapZoomOutLabel,
              onTap: onZoomOut,
            ),
          ],
        ),
      ],
    );
  }
}

class _ControlSurface extends StatelessWidget {
  const _ControlSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.lift,
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.secondaryForeground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            // A11Y-1: 48dp square target for every control.
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
