import 'package:flutter/material.dart';

import '../domain/rules/derived_alerts.dart';
import 'tokens/app_colors.dart';

/// A fuel level's text/surface pair, on the same thresholds
/// [fleetOverlayStatus] uses (`<=10` critical, `<=20` warning, else
/// success) — so a fuel number never disagrees with the status badge
/// sitting next to it. Shared by the vehicle detail's hero tile and the
/// map's vehicle sheet.
class FuelTone {
  const FuelTone({required this.text, required this.surface});

  final Color text;
  final Color surface;
}

FuelTone fuelToneOf(BuildContext context, double fuelLevel) {
  final theme = Theme.of(context);
  if (fuelLevel <= criticalFuelThreshold) {
    return FuelTone(
      text: theme.colorScheme.onErrorContainer,
      surface: theme.colorScheme.errorContainer,
    );
  }

  final colors = theme.extension<AppColors>()!;
  if (fuelLevel <= lowFuelThreshold) {
    return FuelTone(text: colors.onWarningSoft, surface: colors.warningSoft);
  }
  return FuelTone(text: colors.onSuccessSoft, surface: colors.successSoft);
}

/// The neutral pair for "no reading yet" — an em dash has no fuel level to
/// colour, and painting it green would read as a full tank.
const fuelToneUnknown = FuelTone(
  text: AppColors.mutedForeground,
  surface: AppColors.secondary,
);
