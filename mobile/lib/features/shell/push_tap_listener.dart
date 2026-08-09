import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/push/alert_notifier.dart';
import '../../router/routes.dart';
import '../../state/push_provider.dart';
import '../../state/session_provider.dart';

/// Routes a tapped alert notification to the alert it names.
///
/// Wraps the router's child rather than living inside a screen, so it survives
/// every navigation and catches taps whatever is on screen at the time.
class PushTapListener extends ConsumerStatefulWidget {
  const PushTapListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushTapListener> createState() => _PushTapListenerState();
}

class _PushTapListenerState extends ConsumerState<PushTapListener> {
  StreamSubscription<AlertNotificationTap>? _subscription;

  /// A tap that arrived before the session resolved — held rather than
  /// dropped, because navigating then would be undone by the router's
  /// redirect to `/login`.
  AlertNotificationTap? _pending;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(alertNotifierProvider).taps.listen(_dispatch);
  }

  void _dispatch(AlertNotificationTap tap) {
    // Alerts are admin-only (ROLE-2). Only an admin can receive one of these
    // notifications in the first place, so this is belt-and-braces against a
    // role change between the notification and the tap.
    final hasSession = ref.read(sessionProvider).valueOrNull != null;
    if (!hasSession) {
      _pending = tap;
      return;
    }
    if (!ref.read(isAdminProvider)) return;

    // Post-frame: a tap can land while a build is still in flight, and
    // GoRouter has no navigator to push onto yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GoRouter.of(context).push(Routes.alertDetail(tap.alertId));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replays a tap that landed before the session finished resolving.
    ref.listen(sessionProvider, (previous, next) {
      final pending = _pending;
      if (pending != null && next.valueOrNull != null) {
        _pending = null;
        _dispatch(pending);
      }
    });

    return widget.child;
  }
}
