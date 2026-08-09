import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'telemetry_reading.freezed.dart';
part 'telemetry_reading.g.dart';

/// Mirrors the backend's `TelemetryReadingRead` schema — no nullable
/// fields. Every `double` field carries [LooseDoubleConverter] (design §4).
@freezed
sealed class TelemetryReading with _$TelemetryReading {
  const factory TelemetryReading({
    required String id,
    required String deviceId,
    @LooseDoubleConverter() required double latitude,
    @LooseDoubleConverter() required double longitude,
    @LooseDoubleConverter() required double speed,
    @LooseDoubleConverter() required double fuelLevel,
    @LooseDoubleConverter() required double temperature,
    @UtcDateTimeConverter() required DateTime recordedAt,
  }) = _TelemetryReading;

  factory TelemetryReading.fromJson(Map<String, dynamic> json) =>
      _$TelemetryReadingFromJson(json);
}
