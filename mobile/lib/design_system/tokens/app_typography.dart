import 'package:flutter/material.dart';

/// Type scale ported from `frontend/src/index.css` (`--font-sans`, tight
/// heading tracking, `.tabular` tabular figures). See design §2.3.
///
/// `dataLarge`/`dataMedium` have no Material `TextTheme` slot and live only
/// here. Every style omits a hardcoded call-site `fontSize` so dynamic type
/// scales all of them.
class AppTypography {
  const AppTypography._();

  static const _fontFamily = 'Geist';

  static const headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static const bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  static const labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  static const labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  /// KPI values — tabular figures so digits don't reflow their column.
  static const dataLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The dashboard's single hero metric (DASH-1). One per screen — it is
  /// what makes the KPI block read as a headline number with supporting
  /// stats instead of four tiles of equal weight.
  static const dataHero = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 44,
    height: 48 / 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Supporting metrics that sit under a hero number, and the emphasized
  /// value on a list row — deliberately below [dataLarge] so nothing
  /// competes with [dataHero].
  static const dataStat = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Telemetry values, `device_code` — tabular figures.
  static const dataMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
