import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_system/app_theme.dart';
import 'features/shell/bootstrap_screen.dart';
import 'features/shell/push_tap_listener.dart';
import 'router/app_router.dart';
import 'state/session_provider.dart';

/// `MaterialApp.router` + theme + the bootstrap overlay (design §7): while
/// `sessionProvider`'s cold-start bootstrap hasn't resolved even once yet
/// (loading with no previous value), the whole router is replaced by
/// [BootstrapScreen] so `/login` never flashes before the session is known.
/// A later, transient loading state (e.g. mid-login, which carries a
/// previous value via `copyWithPrevious`) does NOT trigger this — that
/// loading is owned by the screen's own submit button instead.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final session = ref.watch(sessionProvider);
    final showBootstrap = session.isLoading && !session.hasValue;

    return MaterialApp.router(
      title: 'IoT Fleet Monitor',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => showBootstrap
          ? const BootstrapScreen()
          : PushTapListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
