import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/alert_notifier.dart';

final alertNotifierProvider = Provider<AlertNotifier>((ref) {
  final notifier = AlertNotifier(FlutterLocalNotificationsPlugin());
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Asks for the notification permission once a session exists, rather than on
/// first launch: a prompt that appears before the user has logged in has no
/// context, and iOS only ever asks once — a decline there is permanent.
///
/// Never throws. A declined permission, an unsupported host, or a plugin that
/// fails to initialise all mean "no notifications", which is not an error
/// worth surfacing over a working app.
Future<void> enableAlertNotifications(Ref ref) async {
  try {
    // `ref.read` itself is inside the try too: AUTH-7's cold-start restore
    // defers this call past a real event-loop turn (see session_provider.dart),
    // so by the time it runs the container it was read from may already be
    // disposed (e.g. a fast logout, or a test's teardown) — that throws on
    // the read itself, before `notifier` even exists.
    final notifier = ref.read(alertNotifierProvider);
    await notifier.initialize();
    await notifier.requestPermission();
  } catch (error, stack) {
    // The doc comment above promises this never throws: an unsupported
    // host or a plugin that never registered its platform channel (e.g.
    // this call site running outside a real app host) both mean "no
    // notifications", not an uncaught error for whatever `unawaited`-called
    // this — login, or AUTH-7's cold-start session restore. Logged (not
    // swallowed) so a real init failure on a real device is diagnosable
    // instead of just silently never notifying.
    debugPrint('Could not enable alert notifications: $error\n$stack');
  }
}
