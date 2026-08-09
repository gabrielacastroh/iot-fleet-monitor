import 'package:flutter/material.dart';

/// Layered micro-shadows, literal port of the `--shadow-*` CSS custom
/// properties in `frontend/src/index.css`. Every Material `elevation` in
/// this app is 0 — depth comes from these instead. See design §2.4.
///
/// Alpha bytes below are `rgb(15 23 42 / a)` converted to ARGB
/// (`round(a * 255)`), e.g. 0.04 -> 0x0A.
class AppShadows {
  const AppShadows._();

  /// Cards, list rows.
  static const soft = [
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x080F172A), offset: Offset(0, 1), blurRadius: 3),
  ];

  /// Raised cards, FAB, map marker sheet.
  static const lift = [
    BoxShadow(
      color: Color(0x0F0F172A),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -8,
    ),
  ];

  /// Dialogs, bottom sheets.
  static const overlay = [
    BoxShadow(
      color: Color(0x1F0F172A),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Color(0x3D0F172A),
      offset: Offset(0, 24),
      blurRadius: 48,
      spreadRadius: -24,
    ),
  ];
}
