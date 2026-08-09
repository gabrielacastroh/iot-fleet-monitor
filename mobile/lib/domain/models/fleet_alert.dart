import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'fleet_alert.freezed.dart';
part 'fleet_alert.g.dart';

/// Mirrors the backend's `AlertRead` schema. Named `FleetAlert` (not
/// `Alert`) to avoid colliding with Flutter's own `Alert*` widgets (design
/// §4). There is exactly one wire value for [alertType] today
/// (`"low_fuel"`) and no `severity` field anywhere in this domain (ALT-6).
enum AlertType {
  @JsonValue('low_fuel')
  lowFuel,

  /// Fail-safe for a future wire value this build doesn't know about yet —
  /// same reasoning as [UserRole]'s unknown-role fallback (design §4): an
  /// unrecognized type must not crash the parse.
  unknown,
}

@freezed
sealed class FleetAlert with _$FleetAlert {
  const factory FleetAlert({
    required String id,
    required String deviceId,
    @JsonKey(unknownEnumValue: AlertType.unknown) required AlertType alertType,
    required String message,
    required bool isResolved,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _FleetAlert;

  factory FleetAlert.fromJson(Map<String, dynamic> json) =>
      _$FleetAlertFromJson(json);
}
