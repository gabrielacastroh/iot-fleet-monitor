import 'package:flutter/material.dart';

import 'tokens/app_colors.dart';
import 'tokens/app_radii.dart';
import 'tokens/app_typography.dart';

/// Wires the design tokens (§2.1–2.4) into a [ThemeData]. `elevation` is 0
/// everywhere — depth comes from `AppShadows`, applied per-component.
class AppTheme {
  const AppTheme._();

  static final ThemeData light = _build();

  static ThemeData _build() {
    const colorScheme = ColorScheme.light(
      surface: AppColors.card,
      onSurface: AppColors.foreground,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      primaryContainer: AppColors.primarySoft,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      errorContainer: AppColors.destructiveSoft,
      // Accessibility fix (design §2.1): the web's text-destructive on a
      // soft surface is 3.4:1, below WCAG AA. #B91C1C is 5.88:1.
      onErrorContainer: Color(0xFFB91C1C),
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      onSurfaceVariant: AppColors.mutedForeground,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      extensions: const [AppColors.light],
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      // The one persistent chrome surface on every authenticated screen, so
      // it is themed once here rather than per-screen: flat white, a pill
      // indicator in `primarySoft`, and the same muted/primary pair every
      // other control uses for unselected/selected. `AppShell` draws the
      // hairline that separates it from the scrolling content.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                )
              : AppTypography.labelSmall.copyWith(
                  color: AppColors.mutedForeground,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.mutedForeground,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.foreground,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelSmall: AppTypography.labelSmall,
      ),
      fontFamily: 'Geist',
    );
  }
}
