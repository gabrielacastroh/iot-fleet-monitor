import 'package:flutter/material.dart';

/// The only file in this app allowed to contain a raw hex literal. Every
/// value is a literal port of `frontend/src/index.css`. See design §2.1.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ring,
    required this.success,
    required this.onSuccess,
    required this.successSoft,
    required this.onSuccessSoft,
    required this.warning,
    required this.onWarning,
    required this.warningSoft,
    required this.onWarningSoft,
    required this.onDestructiveSoft,
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarMuted,
    required this.sidebarBorder,
    required this.sidebarActive,
  });

  final Color ring;

  final Color success;
  final Color onSuccess;
  final Color successSoft;
  final Color onSuccessSoft;

  final Color warning;
  final Color onWarning;
  final Color warningSoft;
  final Color onWarningSoft;

  /// Deliberate divergence from the web: `#B91C1C`, replacing the web's
  /// `text-destructive` on a soft surface, which fails WCAG AA (see §2.1).
  final Color onDestructiveSoft;

  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarMuted;
  final Color sidebarBorder;
  final Color sidebarActive;

  static const light = AppColors(
    ring: Color(0xFF2563EB),
    success: Color(0xFF22C55E),
    onSuccess: Color(0xFFFFFFFF),
    successSoft: Color(0xFFF0FDF4),
    onSuccessSoft: Color(0xFF15803D),
    warning: Color(0xFFF59E0B),
    onWarning: Color(0xFFFFFFFF),
    warningSoft: Color(0xFFFFFBEB),
    onWarningSoft: Color(0xFFB45309),
    onDestructiveSoft: Color(0xFFB91C1C),
    sidebar: Color(0xFF0F172A),
    sidebarForeground: Color(0xFFF8FAFC),
    sidebarMuted: Color(0xFF94A3B8),
    sidebarBorder: Color(0xFF1E293B),
    sidebarActive: Color(0xFF1E293B),
  );

  // Colors that map cleanly onto ColorScheme slots — exposed here too so
  // app_theme.dart has a single source for the literal hex table.
  static const background = Color(0xFFF8FAFC);
  static const foreground = Color(0xFF0F172A);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2563EB);
  static const primaryForeground = Color(0xFFFFFFFF);
  static const primarySoft = Color(0xFFEFF6FF);
  static const destructive = Color(0xFFEF4444);
  static const destructiveForeground = Color(0xFFFFFFFF);
  static const destructiveSoft = Color(0xFFFEF2F2);
  static const secondary = Color(0xFFF1F5F9);
  static const secondaryForeground = Color(0xFF0F172A);
  static const mutedForeground = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  @override
  AppColors copyWith({
    Color? ring,
    Color? success,
    Color? onSuccess,
    Color? successSoft,
    Color? onSuccessSoft,
    Color? warning,
    Color? onWarning,
    Color? warningSoft,
    Color? onWarningSoft,
    Color? onDestructiveSoft,
    Color? sidebar,
    Color? sidebarForeground,
    Color? sidebarMuted,
    Color? sidebarBorder,
    Color? sidebarActive,
  }) {
    return AppColors(
      ring: ring ?? this.ring,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successSoft: successSoft ?? this.successSoft,
      onSuccessSoft: onSuccessSoft ?? this.onSuccessSoft,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningSoft: warningSoft ?? this.warningSoft,
      onWarningSoft: onWarningSoft ?? this.onWarningSoft,
      onDestructiveSoft: onDestructiveSoft ?? this.onDestructiveSoft,
      sidebar: sidebar ?? this.sidebar,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarActive: sidebarActive ?? this.sidebarActive,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      ring: Color.lerp(ring, other.ring, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      onSuccessSoft: Color.lerp(onSuccessSoft, other.onSuccessSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      onWarningSoft: Color.lerp(onWarningSoft, other.onWarningSoft, t)!,
      onDestructiveSoft: Color.lerp(
        onDestructiveSoft,
        other.onDestructiveSoft,
        t,
      )!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarForeground: Color.lerp(
        sidebarForeground,
        other.sidebarForeground,
        t,
      )!,
      sidebarMuted: Color.lerp(sidebarMuted, other.sidebarMuted, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      sidebarActive: Color.lerp(sidebarActive, other.sidebarActive, t)!,
    );
  }
}
