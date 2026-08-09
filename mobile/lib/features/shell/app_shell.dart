import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/offline_banner.dart';
import '../../design_system/components/two_pane_row.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../state/alerts_provider.dart';
import '../../state/connectivity_provider.dart';
import '../../state/realtime_provider.dart';
import '../../state/session_provider.dart';
import 'shell_nav_items.dart';

/// The authenticated `StatefulShellRoute` body — and the sole owner of the
/// WebSocket connection's lifecycle (design §6.1). Watching
/// [wsEventRouterProvider] in [build] is what creates/connects the socket
/// in the first place; that watch, plus this shell only ever mounting once
/// [sessionProvider] is authenticated (the router guard), is the whole
/// "exactly one socket, only while authenticated" story (WS-1/WS-2).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      // WS-5: paused/detached MAY drop the socket without an active
      // reconnect loop — holding one in the background drains battery and
      // produces a phantom "connected" UI. `suspend()` closes with code
      // 1000 and does not schedule a reconnect.
      onPause: () => ref.read(telemetrySocketProvider).suspend(),
      onDetach: () => ref.read(telemetrySocketProvider).suspend(),
      onResume: _onResume,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// WS-5/AUTH-8: the proactive `exp` check runs FIRST — a token that
  /// expired while backgrounded must never reach a resumed socket.
  void _onResume() {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return;
    if (session.claims.isExpired) {
      ref.read(sessionProvider.notifier).forceLogout();
      return;
    }
    ref.read(telemetrySocketProvider).resume(session.token);
  }

  @override
  Widget build(BuildContext context) {
    // The single fan-out's one and only subscriber for the whole
    // authenticated session — every WS event flows through here.
    ref.watch(wsEventRouterProvider);

    ref.listen<bool>(connectivityProvider, (previous, isOnline) {
      // WS-5: connectivity regain is a stronger reconnect signal than a
      // timer — reset the backoff budget and reconnect immediately.
      if (previous == false && isOnline) {
        final token = ref.read(sessionProvider).valueOrNull?.token;
        if (token != null) {
          ref.read(telemetrySocketProvider).resume(token);
        }
      }
    });

    final isOnline = ref.watch(connectivityProvider);

    // RESP-1: ≥600dp switches primary navigation from a bottom
    // `NavigationBar` to a `NavigationRail` (dark, `sidebar` tokens).
    // Measured against the full screen width (not the branch content's
    // local `LayoutBuilder` constraints, unlike the vehicles/alerts
    // two-pane switch below it) since this decides the chrome itself.
    final isCompact = MediaQuery.sizeOf(context).width < tabletBreakpoint;

    // SAFE-1: every branch screen (Dashboard/Vehicles/Map/Alertas/Perfil)
    // renders its own title/search-field header directly at the top of its
    // body with no `AppBar` of its own — this `SafeArea` is the ONE place
    // that insets all of them below the status bar/notch, instead of a
    // per-screen `Padding` band-aid repeated five times. `bottom` is only
    // respected on the tablet rail layout: on the compact phone layout the
    // Material `NavigationBar` already pads itself for the home-indicator
    // safe area (see its own `MediaQuery.paddingOf` usage), so insetting
    // the body's bottom too would just add a redundant gap above it.
    final body = SafeArea(
      bottom: !isCompact,
      child: Column(
        children: [
          // OFF-2: the banner shifts content down, it never covers it.
          if (!isOnline) const OfflineBanner(),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );

    if (isCompact) {
      return Scaffold(
        body: body,
        // The bar itself is flat (see `AppTheme.navigationBarTheme`); this
        // hairline is what separates it from the scrolling content, instead
        // of a shadow.
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: widget.navigationShell.goBranch,
            destinations: [
              for (final item in shellNavItems)
                NavigationDestination(
                  icon: _NavIcon(item: item, icon: item.icon),
                  selectedIcon: _NavIcon(item: item, icon: item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        ),
      );
    }

    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            backgroundColor: colors.sidebar,
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: widget.navigationShell.goBranch,
            labelType: NavigationRailLabelType.all,
            indicatorColor: colors.sidebarActive,
            selectedIconTheme: IconThemeData(color: colors.sidebarForeground),
            unselectedIconTheme: IconThemeData(color: colors.sidebarMuted),
            selectedLabelTextStyle: AppTypography.labelSmall.copyWith(
              color: colors.sidebarForeground,
            ),
            unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(
              color: colors.sidebarMuted,
            ),
            destinations: [
              for (final item in shellNavItems)
                NavigationRailDestination(
                  icon: _NavIcon(item: item, icon: item.icon),
                  selectedIcon: _NavIcon(item: item, icon: item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: colors.sidebarBorder),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// A destination icon, badged when the item opts in and there is something to
/// report.
///
/// The badge is a bare dot, not a count: at this size a two-digit number is
/// unreadable, and the tab's own screen already states the exact figure. It
/// answers "is there anything?", which is the only question a nav bar can
/// usefully answer.
class _NavIcon extends ConsumerWidget {
  const _NavIcon({required this.item, required this.icon});

  final ShellNavItem item;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!item.badges) return Icon(icon);

    // ROLE-2 lives inside this provider: it returns 0 without constructing
    // `alertsProvider` for a non-admin session, so watching it here does not
    // fire `GET /alerts` for them.
    final count = ref.watch(openAlertsBadgeCountProvider);
    if (count == 0) return Icon(icon);

    final colors = Theme.of(context).extension<AppColors>()!;
    // A11Y-5: the dot alone is colour-only, so the count goes out as
    // semantics. Not repeating "Alertas" — the destination already announces
    // its own label, and the reader composes the two.
    return Semantics(
      label: AppStrings.openAlertsBadgeLabel(count),
      child: Badge(
        backgroundColor: colors.warning,
        // No `label`: a two-digit count is unreadable at this size, and the
        // Alertas screen states the exact figure anyway. The dot answers "is
        // there anything?", which is all a nav bar can usefully say.
        child: Icon(icon),
      ),
    );
  }
}
