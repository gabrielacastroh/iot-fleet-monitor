// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_reading.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TelemetryReading _$TelemetryReadingFromJson(
  Map<String, dynamic> json,
) => _TelemetryReading(
  id: json['id'] as String,
  deviceId: json['device_id'] as String,
  latitude: const LooseDoubleConverter().fromJson(json['latitude'] as num),
  longitude: const LooseDoubleConverter().fromJson(json['longitude'] as num),
  speed: const LooseDoubleConverter().fromJson(json['speed'] as num),
  fuelLevel: const LooseDoubleConverter().fromJson(json['fuel_level'] as num),
  temperature: const LooseDoubleConverter().fromJson(
    json['temperature'] as num,
  ),
  recordedAt: const UtcDateTimeConverter().fromJson(
    json['recorded_at'] as String,
  ),
);

Map<String, dynamic> _$TelemetryReadingToJson(_TelemetryReading instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'latitude': const LooseDoubleConverter().toJson(instance.latitude),
      'longitude': const LooseDoubleConverter().toJson(instance.longitude),
      'speed': const LooseDoubleConverter().toJson(instance.speed),
      'fuel_level': const LooseDoubleConverter().toJson(instance.fuelLevel),
      'temperature': const LooseDoubleConverter().toJson(instance.temperature),
      'recorded_at': const UtcDateTimeConverter().toJson(instance.recordedAt),
    };
