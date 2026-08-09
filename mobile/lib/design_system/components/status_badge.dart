import 'package:flutter/material.dart';

import '../../domain/rules/fleet_status.dart';
import '../status_tone.dart';
import '../tokens/app_durations.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A status dot + Spanish label, per [statusToneOf] — color, icon and text
/// always render together (A11Y-5, never color alone). The dot only
/// pulses when [status] is `active`, [socketOpen] is true, and the device
/// hasn't disabled animations (design §2.2).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.status,
    this.socketOpen = false,
    this.showDot = true,
    super.key,
  });

  final FleetStatus status;
  final bool socketOpen;

  /// Drops the leading dot for callers that already show one elsewhere —
  /// on a tinted chip sitting next to a dotted avatar, dot + icon + label
  /// is the same state said three times.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tone = statusToneOf(context, status);
    final shouldPulse =
        status == FleetStatus.active &&
        socketOpen &&
        AppDurations.of(context, AppDurations.base) != Duration.zero;

    return Semantics(
      label: tone.label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              shouldPulse
                  ? PulsingStatusDot(color: tone.dot)
                  : _Dot(color: tone.dot),
              const SizedBox(width: AppSpacing.xs),
            ],
            Icon(tone.icon, size: 14, color: tone.softText),
            const SizedBox(width: AppSpacing.xs),
            // A11Y-3: at 2.0x text scale "Sin señal" is wider than the
            // column this badge sits in, and a bare `Text` in a
            // `MainAxisSize.min` row has no way to give ground.
            Flexible(
              child: Text(
                tone.label,
                style: AppTypography.labelSmall.copyWith(color: tone.softText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [StatusBadge] on the tinted chip surface the mockups put behind it —
/// the vehicles list row and the vehicle detail's app bar. The badge keeps
/// owning the pulse animation and the A11Y-5 semantics; this only adds the
/// container.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.status,
    this.socketOpen = false,
    this.showDot = false,
    super.key,
  });

  final FleetStatus status;
  final bool socketOpen;

  /// Off by default: every surface that uses the pill today already shows a
  /// dot on the adjacent avatar, and dot + icon + label is the same state
  /// said three times inside one 90dp chip.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tone = statusToneOf(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: StatusBadge(
        status: status,
        socketOpen: socketOpen,
        showDot: showDot,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class PulsingStatusDot extends StatefulWidget {
  const PulsingStatusDot({required this.color, super.key});

  final Color color;

  @override
  State<PulsingStatusDot> createState() => PulsingStatusDotState();
}

class PulsingStatusDotState extends State<PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          opacity: 1 - (t * 0.55),
          child: Transform.scale(scale: 1 - (t * 0.15), child: child),
        );
      },
      child: _Dot(color: widget.color),
    );
  }
}
