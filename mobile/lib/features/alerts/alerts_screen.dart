import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure.dart';
import '../../design_system/components/app_empty_state.dart';
import '../../design_system/components/async_state_view.dart';
import '../../design_system/components/two_pane_row.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../domain/models/fleet_alert.dart';
import '../../router/routes.dart';
import '../../state/alerts_provider.dart';
import '../../state/cached.dart';
import '../../state/connectivity_provider.dart';
import '../../state/devices_provider.dart';
import 'state/alert_filter_provider.dart';
import 'widgets/alert_list_card.dart';
import 'widgets/alert_tab_chip.dart';

/// ALT-1..ALT-5: the admin alerts list — three triage tabs, each mapped to
/// the only `is_resolved` filter `GET /alerts` supports (ALT-1). Only the
/// Pendientes tab is cache-backed ([alertsProvider], design §5.3); the
/// other two are uncached, online-only passthroughs
/// ([alertsByFilterProvider]). Reachability is decided at the router (not
/// here) — this widget is only ever built for an admin session
/// (ROLE-2/ROLE-3).
///
/// RESP-1: at ≥600dp this becomes the left pane of a list-detail two-pane
/// layout, paired with a "pick an alert" placeholder — the companion
/// detail pane for an actual selection is [AlertDetailScreen]'s own wide
/// layout (same fallback as the vehicles branch, design §14 risk #3).
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = AlertsListBody(
          onSelectAlert: (context, alert) =>
              context.push(Routes.alertDetail(alert.id), extra: alert),
        );

        if (constraints.maxWidth < tabletBreakpoint) return list;

        return twoPaneRow(
          list: list,
          detail: const AppEmptyState(
            icon: Icons.notifications_outlined,
            title: AppStrings.alertsSelectPromptTitle,
            body: AppStrings.alertsSelectPromptBody,
          ),
        );
      },
    );
  }
}

class AlertsListBody extends ConsumerWidget {
  const AlertsListBody({required this.onSelectAlert, super.key});

  final void Function(BuildContext context, FleetAlert alert) onSelectAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(alertFilterProvider);
    final isOnline = ref.watch(connectivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.alertsTitle, style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.alertsSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TabChips(selected: filter.tab),
        _SortToolbar(tab: filter.tab, sort: filter.sort),
        Expanded(
          child: filter.tab == AlertListTab.pending
              ? _PendingList(
                  isOnline: isOnline,
                  sort: filter.sort,
                  onSelectAlert: onSelectAlert,
                )
              : _FilteredList(
                  tab: filter.tab,
                  isOnline: isOnline,
                  sort: filter.sort,
                  onSelectAlert: onSelectAlert,
                ),
        ),
      ],
    );
  }
}

/// Watching all three feeds is what makes every chip carry a count from
/// the first frame, and it costs two extra `GET /alerts` per visit — the
/// Resueltas/Todas passthroughs are uncached by design (§5.3), so there is
/// no stored value to read instead. Admin-only screen, so the cost is
/// bounded; drop the two `alertsByFilterProvider` watches here if it ever
/// stops being worth it, and the chips fall back to showing a number only
/// for the tab that has been opened.
///
/// Offline those two resolve to an error, `valueOrNull` is null, and
/// [AlertTabChip] renders no number — never a `0` the user would read as
/// "none".
class _TabChips extends ConsumerWidget {
  const _TabChips({required this.selected});

  final AlertListTab selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countByTab = {
      AlertListTab.pending: ref.watch(alertsProvider).valueOrNull?.value.length,
      AlertListTab.resolved: ref
          .watch(alertsByFilterProvider(true))
          .valueOrNull
          ?.length,
      AlertListTab.all: ref
          .watch(alertsByFilterProvider(null))
          .valueOrNull
          ?.length,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final (index, tab) in AlertListTab.values.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            AlertTabChip(
              // Stable handle for tests: the visible label alone would be
              // ambiguous against a section title using the same word.
              key: ValueKey('alert_tab_chip_${tab.name}'),
              tab: tab,
              isSelected: tab == selected,
              count: countByTab[tab],
              onTap: () => ref.read(alertFilterProvider.notifier).setTab(tab),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortToolbar extends ConsumerWidget {
  const _SortToolbar({required this.tab, required this.sort});

  final AlertListTab tab;
  final AlertSortOption sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _sectionTitle(ref),
              style: AppTypography.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: PopupMenuButton<AlertSortOption>(
              initialValue: sort,
              onSelected: (value) =>
                  ref.read(alertFilterProvider.notifier).setSort(value),
              tooltip: AppStrings.alertsSortLabel,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => [
                for (final option in AlertSortOption.values)
                  PopupMenuItem(value: option, child: Text(_sortLabel(option))),
              ],
              child: Container(
                // A11Y-1: the label alone is a 34dp-tall tap target.
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _sortLabel(sort),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sectionTitle(WidgetRef ref) {
    if (tab != AlertListTab.pending) {
      return tab == AlertListTab.resolved
          ? AppStrings.alertsResolvedSectionTitle
          : AppStrings.alertsAllSectionTitle;
    }
    final pending = ref.watch(alertsProvider).valueOrNull?.value.length ?? 0;
    return AppStrings.alertsPendingSectionTitle(pending);
  }
}

String _sortLabel(AlertSortOption option) => switch (option) {
  AlertSortOption.newest => AppStrings.alertsSortNewest,
  AlertSortOption.oldest => AppStrings.alertsSortOldest,
};

List<FleetAlert> _sorted(List<FleetAlert> alerts, AlertSortOption sort) {
  final ordered = [...alerts]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sort == AlertSortOption.newest ? ordered : ordered.reversed.toList();
}

class _PendingList extends ConsumerWidget {
  const _PendingList({
    required this.isOnline,
    required this.sort,
    required this.onSelectAlert,
  });

  final bool isOnline;
  final AlertSortOption sort;
  final void Function(BuildContext context, FleetAlert alert) onSelectAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return AsyncStateView<List<FleetAlert>>(
      state: alertsAsync,
      isEmpty: (alerts) => alerts.isEmpty,
      data: (alerts, cachedAt) => _AlertsListView(
        alerts: _sorted(alerts, sort),
        isOnline: isOnline,
        onSelectAlert: onSelectAlert,
      ),
      empty: const AppEmptyState(
        icon: Icons.check_circle_outline,
        title: AppStrings.alertsEmptyPendingTitle,
        body: AppStrings.alertsEmptyPendingBody,
      ),
      onRetry: () => ref.invalidate(alertsProvider),
    );
  }
}

class _FilteredList extends ConsumerWidget {
  const _FilteredList({
    required this.tab,
    required this.isOnline,
    required this.sort,
    required this.onSelectAlert,
  });

  final AlertListTab tab;
  final bool isOnline;
  final AlertSortOption sort;
  final void Function(BuildContext context, FleetAlert alert) onSelectAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterAsync = ref.watch(alertsByFilterProvider(tab.isResolved));

    // This feed is never cached (design §5.3) — there is no "previous
    // value" for AsyncStateView's offline fork to key off, so the offline
    // empty state is hand-rolled ahead of it, same as OFF-3b in
    // `telemetry_section.dart`.
    if (filterAsync.hasError && filterAsync.error is NetworkFailure) {
      return const AppEmptyState(
        icon: Icons.cloud_off,
        title: AppStrings.offlineBadgeMessage,
        body: AppStrings.offlineNoCacheMessage,
      );
    }

    return AsyncStateView<List<FleetAlert>>(
      state: filterAsync.whenData(Cached.new),
      isEmpty: (alerts) => alerts.isEmpty,
      data: (alerts, cachedAt) => _AlertsListView(
        alerts: _sorted(alerts, sort),
        isOnline: isOnline,
        onSelectAlert: onSelectAlert,
      ),
      empty: AppEmptyState(
        icon: Icons.check_circle_outline,
        title: tab == AlertListTab.resolved
            ? AppStrings.alertsEmptyResolvedTitle
            : AppStrings.alertsEmptyAllTitle,
        body: tab == AlertListTab.resolved
            ? AppStrings.alertsEmptyResolvedBody
            : AppStrings.alertsEmptyAllBody,
      ),
      onRetry: () => ref.invalidate(alertsByFilterProvider(tab.isResolved)),
    );
  }
}

class _AlertsListView extends ConsumerWidget {
  const _AlertsListView({
    required this.alerts,
    required this.isOnline,
    required this.onSelectAlert,
  });

  final List<FleetAlert> alerts;
  final bool isOnline;
  final void Function(BuildContext context, FleetAlert alert) onSelectAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Joined against the already-loaded fleet list so a row can name its
    // vehicle; never fetched for this screen's sake.
    final devices = ref.watch(devicesProvider).valueOrNull?.value ?? const [];
    final deviceById = {for (final device in devices) device.id: device};

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AlertListCard(
            alert: alert,
            device: deviceById[alert.deviceId],
            onTap: () => onSelectAlert(context, alert),
            onResolve: () => _resolve(context, ref, alert),
            resolveDisabledReason: isOnline
                ? null
                : AppStrings.resolveRequiresConnectionMessage,
          ),
        );
      },
    );
  }

  /// ALT-3/ALT-4: the optimistic update/rollback itself lives in
  /// [AlertsNotifier.resolve]; this handler owns the failure toast + retry
  /// (design §9) and refreshes the uncached Resueltas/Todas tabs, which
  /// [AlertsNotifier] has no reason to know about.
  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    FleetAlert alert,
  ) async {
    try {
      await ref.read(alertsProvider.notifier).resolve(alert.id);
      ref.invalidate(alertsByFilterProvider(true));
      ref.invalidate(alertsByFilterProvider(null));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.resolveFailedMessage),
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: () => _resolve(context, ref, alert),
          ),
        ),
      );
    }
  }
}
