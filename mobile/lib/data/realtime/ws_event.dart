import 'dart:convert';

import '../../domain/models/fleet_alert.dart';
import '../../domain/models/telemetry_reading.dart';

/// `{"type": "<event>", "data": {...}}` — the exact 3 event types
/// `/ws/telemetry` sends (backend `app/websocket/events.py`). WS-10: a
/// missing/unrecognized `type` or a malformed payload MUST be dropped
/// silently, never thrown — see [parseWsEvent].
sealed class WsEvent {
  const WsEvent();
}

/// WS-6. The payload carries every field of `TelemetryReadingRead` except
/// `id` (sent as `reading_id`), so it reuses [TelemetryReading] as-is.
final class TelemetryUpdatedWsEvent extends WsEvent {
  const TelemetryUpdatedWsEvent(this.reading);

  final TelemetryReading reading;
}

/// WS-7 (admin_only server-side). Still not enough to build a [FleetAlert]
/// — `is_resolved` is absent — so receipt keeps triggering
/// `ref.invalidate(alertsProvider)` rather than patching the list.
///
/// [id] and [message] are carried because the server has always sent them and
/// a local notification needs both: the text to show, and the id to route to
/// when it is tapped. They are the payload's, never derived.
final class AlertCreatedWsEvent extends WsEvent {
  const AlertCreatedWsEvent({required this.id, required this.message});

  final String id;
  final String message;
}

/// WS-8 (admin_only server-side). Deliberately does NOT carry `message`/
/// `created_at` — the server payload lacks them, so this must stay an
/// invalidation signal, never a patch source.
final class AlertResolvedWsEvent extends WsEvent {
  const AlertResolvedWsEvent({
    required this.id,
    required this.deviceId,
    required this.alertType,
  });

  final String id;
  final String deviceId;
  final AlertType alertType;
}

/// Returns `null` (WS-10) for malformed JSON, a missing/unrecognized `type`,
/// or a `data` shape that doesn't match the expected event — never throws.
WsEvent? parseWsEvent(String raw) {
  try {
    final envelope = jsonDecode(raw);
    if (envelope is! Map<String, dynamic>) return null;

    final type = envelope['type'];
    final data = envelope['data'];
    if (type is! String || data is! Map<String, dynamic>) return null;

    return switch (type) {
      'telemetry_updated' => TelemetryUpdatedWsEvent(
        TelemetryReading.fromJson(_remapReadingId(data)),
      ),
      'alert_created' => AlertCreatedWsEvent(
        id: data['id'] as String,
        message: data['message'] as String,
      ),
      'alert_resolved' => AlertResolvedWsEvent(
        id: data['id'] as String,
        deviceId: data['device_id'] as String,
        alertType: _parseAlertType(data['alert_type']),
      ),
      _ => null,
    };
  } catch (_) {
    // Any parse/type-cast failure on a recognized `type` is still WS-10:
    // dropped silently, not surfaced as a crash.
    return null;
  }
}

/// [TelemetryReading] expects `id`; the wire payload sends `reading_id`.
Map<String, dynamic> _remapReadingId(Map<String, dynamic> data) {
  final remapped = Map<String, dynamic>.from(data)..remove('reading_id');
  remapped['id'] = data['reading_id'];
  return remapped;
}

AlertType _parseAlertType(Object? value) =>
    value == 'low_fuel' ? AlertType.lowFuel : AlertType.unknown;
