import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/tokens/app_colors.dart';

void main() {
  group('AppTheme.light — ColorScheme pinned hex values', () {
    final theme = AppTheme.light;
    final scheme = theme.colorScheme;

    test('surface colors', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(scheme.onSurface, const Color(0xFF0F172A));
      expect(scheme.surface, const Color(0xFFFFFFFF));
    });

    test('primary colors', () {
      expect(scheme.primary, const Color(0xFF2563EB));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.primaryContainer, const Color(0xFFEFF6FF));
    });

    test('destructive maps onto error/onError/errorContainer', () {
      expect(scheme.error, const Color(0xFFEF4444));
      expect(scheme.onError, const Color(0xFFFFFFFF));
      expect(scheme.errorContainer, const Color(0xFFFEF2F2));
      // The accessibility-fix token: #B91C1C, 5.88:1 on errorContainer.
      expect(scheme.onErrorContainer, const Color(0xFFB91C1C));
    });

    test('secondary/muted/border colors', () {
      expect(scheme.secondary, const Color(0xFFF1F5F9));
      expect(scheme.onSecondary, const Color(0xFF0F172A));
      expect(scheme.onSurfaceVariant, const Color(0xFF64748B));
      expect(scheme.outline, const Color(0xFFE2E8F0));
    });

    test(
      'elevation is 0 app-wide (depth comes from AppShadows, not Material elevation)',
      () {
        expect(theme.cardTheme.elevation, 0);
      },
    );
  });

  group('AppTheme.light — AppColors ThemeExtension pinned hex values', () {
    final colors = AppTheme.light.extension<AppColors>()!;

    test('success family incl. the accessibility-fix onSuccessSoft', () {
      expect(colors.success, const Color(0xFF22C55E));
      expect(colors.successSoft, const Color(0xFFF0FDF4));
      expect(colors.onSuccessSoft, const Color(0xFF15803D));
    });

    test('warning family incl. the accessibility-fix onWarningSoft', () {
      expect(colors.warning, const Color(0xFFF59E0B));
      expect(colors.warningSoft, const Color(0xFFFFFBEB));
      expect(colors.onWarningSoft, const Color(0xFFB45309));
    });

    test('sidebar family', () {
      expect(colors.sidebar, const Color(0xFF0F172A));
      expect(colors.sidebarForeground, const Color(0xFFF8FAFC));
      expect(colors.sidebarMuted, const Color(0xFF94A3B8));
      expect(colors.sidebarBorder, const Color(0xFF1E293B));
      expect(colors.sidebarActive, const Color(0xFF1E293B));
    });

    test('ring token', () {
      expect(colors.ring, const Color(0xFF2563EB));
    });
  });
}
