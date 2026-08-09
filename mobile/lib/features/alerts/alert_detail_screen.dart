import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure.dart';
import '../../core/time/app_format.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_empty_state.dart';
import '../../design_system/components/app_error_state.dart';
import '../../design_system/components/app_skeleton.dart';
import '../../design_system/components/two_pane_row.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../domain/models/fleet_alert.dart';
import '../../router/routes.dart';
import '../../state/alerts_provider.dart';
import '../../state/connectivity_provider.dart';
import 'alerts_screen.dart';

/// ALT-2: renders from [alert] when navigated to in-app (the alerts
/// list's `context.push(..., extra: alert)`); otherwise resolves it
/// through [alertByIdProvider]'s 4-step cold-deep-link fallback chain
/// (design §7), ending in a not-found state rather than a crash.
class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({
    required this.alertId,
    this.deviceId,
    this.alert,
    super.key,
  });

  final String alertId;
  final String? deviceId;
  final FleetAlert? alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passedAlert = alert;
    if (passedAlert != null) {
      return _AlertDetailBody(alert: passedAlert);
    }

    final resolvedAsync = ref.watch(
      alertByIdProvider((alertId: alertId, deviceId: deviceId)),
    );

    return resolvedAsync.when(
      loading: () => const Scaffold(body: AppSkeleton()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.alertDetailTitle)),
        body: AppErrorState(
          failure: error is Failure ? error : UnknownFailure(cause: error),
          onRetry: () => ref.invalidate(
            alertByIdProvider((alertId: alertId, deviceId: deviceId)),
          ),
        ),
      ),
      data: (found) {
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text(AppStrings.alertDetailTitle)),
            body: AppEmptyState(
              icon: Icons.search_off,
              title: AppStrings.alertNotFoundTitle,
              body: AppStrings.alertNotFoundBody,
              action: OutlinedButton(
                onPressed: () => context.go(Routes.alerts),
                child: const Text(AppStrings.alertsViewAllLabel),
              ),
            ),
          );
        }
        return _AlertDetailBody(alert: found);
      },
    );
  }
}

class _AlertDetailBody extends ConsumerWidget {
  const _AlertDetailBody({required this.alert});

  final FleetAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = _AlertDetailContent(alert: alert);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.alertDetailTitle)),
      // RESP-1: at ≥600dp this screen also renders as the tablet companion
      // pane on the right, with the same alerts list on the left —
      // selecting a different alert here replaces the current detail route
      // (`pushReplacement`) instead of stacking a new one.
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < tabletBreakpoint) return detail;
          return twoPaneRow(
            list: AlertsListBody(
              onSelectAlert: (context, selected) => context.pushReplacement(
                Routes.alertDetail(selected.id, deviceId: selected.deviceId),
                extra: selected,
              ),
            ),
            detail: detail,
          );
        },
      ),
    );
  }
}

class _AlertDetailContent extends ConsumerWidget {
  const _AlertDetailContent({required this.alert});

  final FleetAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isOnline = ref.watch(connectivityProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_gas_station, color: colors.warning, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text(alert.message, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormat.dateTime(alert.createdAt),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (alert.isResolved)
            Text(
              AppStrings.alertResolvedLabel,
              style: AppTypography.labelLarge.copyWith(
                color: colors.onSuccessSoft,
              ),
            )
          else
            // ALT-5: unified with alerts_screen.dart's `AlertTile` — a
            // genuinely disabled control whose semantics label carries the
            // offline reason, not an informational row next to an always
            // "live-looking" button.
            Semantics(
              label: isOnline
                  ? AppStrings.resolveAlertLabel
                  : AppStrings.resolveRequiresConnectionMessage,
              button: true,
              child: ExcludeSemantics(
                child: AppButton(
                  label: AppStrings.resolveAlertLabel,
                  onPressed: isOnline ? () => _resolve(context, ref) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(alertsProvider.notifier).resolve(alert.id);
      if (!context.mounted) return;
      context.pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.resolveFailedMessage),
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: () => _resolve(context, ref),
          ),
        ),
      );
    }
  }
}
