// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Device _$DeviceFromJson(Map<String, dynamic> json) => _Device(
  id: json['id'] as String,
  vehicleName: json['vehicle_name'] as String,
  deviceCode: json['device_code'] as String,
  plate: json['plate'] as String,
  isActive: json['is_active'] as bool,
  lastSeenAt: _$JsonConverterFromJson<String, DateTime>(
    json['last_seen_at'],
    const UtcDateTimeConverter().fromJson,
  ),
  createdAt: const UtcDateTimeConverter().fromJson(
    json['created_at'] as String,
  ),
);

Map<String, dynamic> _$DeviceToJson(_Device instance) => <String, dynamic>{
  'id': instance.id,
  'vehicle_name': instance.vehicleName,
  'device_code': instance.deviceCode,
  'plate': instance.plate,
  'is_active': instance.isActive,
  'last_seen_at': _$JsonConverterToJson<String, DateTime>(
    instance.lastSeenAt,
    const UtcDateTimeConverter().toJson,
  ),
  'created_at': const UtcDateTimeConverter().toJson(instance.createdAt),
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
