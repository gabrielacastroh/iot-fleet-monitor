import 'package:flutter/material.dart';

import '../../../design_system/status_tone.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_durations.dart';
import '../../../design_system/tokens/app_shadows.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/rules/fleet_status.dart';
import '../marker_clustering.dart';

/// MAP-1's marker glyph. A compact green capsule (never a classic
/// teardrop/pin) with a centered white truck glyph — the app's brand green
/// (`AppColors.success`, the same tone [statusToneOf] gives `active`)
/// always identifies "this is a vehicle"; the device's actual state
/// (VEH-4/VEH-5, same [statusToneOf] mapping every other status surface
/// already uses) lives only in the small top-right indicator dot, never in
/// the body fill, so the glyph stays small instead of one more oversized
/// colored blob. Color is never the only channel (A11Y-5): the whole
/// marker also exposes a [Semantics] label combining the vehicle name and
/// the status label for screen readers, satisfying that rule without a
/// second visible icon.
class VehicleMarkerIcon extends StatefulWidget {
  const VehicleMarkerIcon({
    required this.status,
    required this.vehicleName,
    required this.onTap,
    this.isSelected = false,
    super.key,
  });

  final FleetStatus status;
  final String vehicleName;
  final VoidCallback onTap;

  /// The marker whose sheet is currently open — it keeps the pressed
  /// halo and a white ring so the card at the bottom is visibly about
  /// *this* vehicle, not whichever one was tapped last.
  final bool isSelected;

  /// The tap hit area (A11Y-1: 48x48dp-class minimum touch target),
  /// deliberately larger than the visible glyph below.
  static const touchTarget = 44.0;

  /// ~35% smaller than the previous 40px teardrop pin.
  static const _bodySize = 26.0;
  static const _indicatorSize = 11.0;

  @override
  State<VehicleMarkerIcon> createState() => _VehicleMarkerIconState();
}

class _VehicleMarkerIconState extends State<VehicleMarkerIcon> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tone = statusToneOf(context, widget.status);
    final colors = Theme.of(context).extension<AppColors>()!;
    final duration = AppDurations.of(context, AppDurations.fast);

    return Semantics(
      label: '${widget.vehicleName} — ${tone.label}',
      button: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: widget.onTap,
          child: SizedBox(
            width: VehicleMarkerIcon.touchTarget,
            height: VehicleMarkerIcon.touchTarget,
            child: Center(
              child: AnimatedScale(
                // Subtle press feedback only (150ms, ~12% scale) — no
                // exaggerated motion, and it collapses to zero under
                // reduced-motion via [AppDurations.of].
                scale: _pressed || widget.isSelected ? 1.12 : 1.0,
                duration: duration,
                curve: AppDurations.enterCurve,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: _pressed || widget.isSelected ? 1 : 0,
                      duration: duration,
                      child: Container(
                        width: VehicleMarkerIcon._bodySize + 12,
                        height: VehicleMarkerIcon._bodySize + 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.success.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    Container(
                      width: VehicleMarkerIcon._bodySize,
                      height: VehicleMarkerIcon._bodySize,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.lift,
                        border: widget.isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: VehicleMarkerIcon._indicatorSize,
                        height: VehicleMarkerIcon._indicatorSize,
                        decoration: BoxDecoration(
                          color: tone.dot,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A density fallback for markers whose positions collide on screen at the
/// current zoom (`marker_clustering.dart`) — a slightly larger badge
/// showing the group's size instead of stacking overlapping glyphs. The
/// ring color is the group's loudest [FleetStatus] tone (critical > alert
/// == noSignal > active > inactive), the same [statusToneOf] mapping every
/// other status surface uses. Tapping zooms the map in on the group
/// instead of opening a sheet — a cluster isn't one vehicle, so MAP-3's
/// per-vehicle sheet doesn't apply here.
class VehicleClusterMarker extends StatelessWidget {
  const VehicleClusterMarker({
    required this.cluster,
    required this.onTap,
    super.key,
  });

  final MarkerCluster cluster;
  final VoidCallback onTap;

  static const _bodySize = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final tone = statusToneOf(context, cluster.highestSeverity);
    final count = cluster.markers.length;

    return Semantics(
      label: AppStrings.mapClusterSemanticsLabel(count),
      button: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: VehicleMarkerIcon.touchTarget,
            height: VehicleMarkerIcon.touchTarget,
            child: Center(
              child: Container(
                width: _bodySize,
                height: _bodySize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.success,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.lift,
                  border: Border.all(color: tone.dot, width: 2),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
