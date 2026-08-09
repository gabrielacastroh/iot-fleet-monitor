import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'device.freezed.dart';
part 'device.g.dart';

/// Mirrors the backend's `DeviceRead` schema. Only [lastSeenAt] is
/// nullable. `deviceCode` is an opaque `String` — server-masked for
/// non-admins and never parsed or "repaired" client-side (design §4).
@freezed
sealed class Device with _$Device {
  const factory Device({
    required String id,
    required String vehicleName,
    required String deviceCode,
    required String plate,
    required bool isActive,
    @UtcDateTimeConverter() DateTime? lastSeenAt,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}
