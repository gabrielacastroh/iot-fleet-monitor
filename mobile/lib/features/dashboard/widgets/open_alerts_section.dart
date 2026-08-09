import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/alert_tile.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/section_link_header.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../router/routes.dart';
import '../../../state/alerts_provider.dart';

/// Admin-only (ROLE-2/ROLE-3): the caller (`DashboardScreen`) only mounts
/// this widget inside an `isAdminProvider` branch, so `alertsProvider` is
/// never constructed — and therefore `GET /alerts` never fires — for a
/// non-admin session. Read-only here; resolving happens on the alerts
/// screen (ALT-5), which is where "Ver todo" leads.
class OpenAlertsSection extends ConsumerWidget {
  const OpenAlertsSection({super.key});

  static const _visibleCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider).valueOrNull?.value ?? const [];
    final visible = alerts.take(_visibleCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLinkHeader(
          title: AppStrings.openAlertsSectionTitle,
          actionLabel: AppStrings.seeAllLabel,
          onAction: () => context.go(Routes.alerts),
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          const _OpenAlertsEmpty()
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, alert) in visible.indexed) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                      color: AppColors.border,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: AlertTile(alert: alert),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A recessed surface rather than a card, matching the live feed's empty
/// state: an all-clear is an absence, not content.
class _OpenAlertsEmpty extends StatelessWidget {
  const _OpenAlertsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.openAlertsEmptyBody,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
