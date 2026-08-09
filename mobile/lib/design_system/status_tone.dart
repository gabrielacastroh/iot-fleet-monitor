import 'package:flutter/material.dart';

import '../domain/rules/fleet_status.dart';
import 'tokens/app_colors.dart';

/// A [FleetStatus]'s color + icon + Spanish label — the single place a
/// fleet state picks its colour (design §2.2, mirrors the web's
/// `STATUS_TONE`). `dot` is the solid fill (status dots, meter bars);
/// `softText`/`softSurface` are the tinted-chip pair.
class StatusTone {
  const StatusTone({
    required this.label,
    required this.icon,
    required this.dot,
    required this.softText,
    required this.softSurface,
  });

  final String label;
  final IconData icon;
  final Color dot;
  final Color softText;
  final Color softSurface;
}

/// The pinned mapping table (design §2.2). `critical` reads `colorScheme`
/// directly (`error`/`errorContainer`/`onErrorContainer`) because
/// destructive maps cleanly onto those `ColorScheme` slots and doesn't get
/// its own `AppColors` entry — see `app_theme.dart`.
StatusTone statusToneOf(BuildContext context, FleetStatus status) {
  final colors = Theme.of(context).extension<AppColors>()!;
  final colorScheme = Theme.of(context).colorScheme;

  return switch (status) {
    FleetStatus.active => StatusTone(
      label: 'Activo',
      icon: Icons.check_circle_outline,
      dot: colors.success,
      softText: colors.onSuccessSoft,
      softSurface: colors.successSoft,
    ),
    FleetStatus.inactive => const StatusTone(
      label: 'Inactivo',
      icon: Icons.power_settings_new,
      dot: AppColors.mutedForeground,
      softText: AppColors.mutedForeground,
      softSurface: AppColors.secondary,
    ),
    FleetStatus.noSignal => StatusTone(
      label: 'Sin señal',
      icon: Icons.signal_cellular_off,
      dot: colors.warning,
      softText: colors.onWarningSoft,
      softSurface: colors.warningSoft,
    ),
    FleetStatus.alert => StatusTone(
      label: 'Alerta',
      icon: Icons.warning_amber_rounded,
      dot: colors.warning,
      softText: colors.onWarningSoft,
      softSurface: colors.warningSoft,
    ),
    FleetStatus.critical => StatusTone(
      label: 'Crítico',
      icon: Icons.error_outline,
      dot: colorScheme.error,
      softText: colors.onDestructiveSoft,
      softSurface: colorScheme.errorContainer,
    ),
  };
}
