import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../design_system/strings/app_strings.dart';

/// What a tapped notification asks the app to open.
@immutable
class AlertNotificationTap {
  const AlertNotificationTap({required this.alertId});

  final String alertId;
}

/// Raises a system notification for an alert the WebSocket just reported.
///
/// These are LOCAL notifications: the app builds and posts them itself, so no
/// Firebase project, APNs key, or paid developer account is involved. The
/// trade-off is the one thing local notifications cannot do — the process has
/// to be alive to receive the socket event, so an app the user has swiped away
/// gets nothing.
class AlertNotifier {
  AlertNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'fleet_alerts';
  static const _channelName = 'Alertas de flota';
  static const _channelDescription =
      'Avisos de alertas abiertas en los vehículos de la flota.';

  final _taps = StreamController<AlertNotificationTap>.broadcast();
  Stream<AlertNotificationTap> get taps => _taps.stream;

  bool _initialized = false;

  /// Safe to call more than once — a second call is a no-op, so a provider
  /// rebuild cannot register the channel or the tap handler twice.
  Future<void> initialize() async {
    if (_initialized) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly in `requestPermission` instead, so the
          // prompt appears when the user has a session rather than on the
          // very first launch, with no context for why.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );
    // Only set once init actually succeeds — flipping this before the
    // `await` meant a failed first attempt (e.g. right after a cold start)
    // locked the notifier into "initialized" forever, so `showAlert` never
    // early-returned but every plugin call it made kept failing silently.
    _initialized = true;
  }

  void _onTap(NotificationResponse response) {
    final alertId = response.payload;
    if (alertId == null || alertId.isEmpty) return;
    _taps.add(AlertNotificationTap(alertId: alertId));
  }

  /// iOS and Android 13+ both need an explicit grant. Returns false when the
  /// user declined, which is a normal state — the app keeps working, it just
  /// never posts a notification.
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// [alertId] rides along as the payload so a tap can route straight to the
  /// alert instead of dumping the user on the dashboard.
  Future<void> showAlert({
    required String alertId,
    required String message,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        // Hashed rather than incremented: re-raising the same alert replaces
        // its notification instead of stacking a duplicate.
        id: alertId.hashCode,
        title: AppStrings.alertNotificationTitle,
        body: message,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: alertId,
      );
    } catch (error, stack) {
      // Never fatal: a failed notification must not take down the WebSocket
      // handler that triggered it.
      debugPrint('Could not show alert notification: $error\n$stack');
    }
  }

  void dispose() => _taps.close();
}
