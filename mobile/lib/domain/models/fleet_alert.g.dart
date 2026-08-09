// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fleet_alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FleetAlert _$FleetAlertFromJson(Map<String, dynamic> json) => _FleetAlert(
  id: json['id'] as String,
  deviceId: json['device_id'] as String,
  alertType: $enumDecode(
    _$AlertTypeEnumMap,
    json['alert_type'],
    unknownValue: AlertType.unknown,
  ),
  message: json['message'] as String,
  isResolved: json['is_resolved'] as bool,
  createdAt: const UtcDateTimeConverter().fromJson(
    json['created_at'] as String,
  ),
);

Map<String, dynamic> _$FleetAlertToJson(_FleetAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'alert_type': _$AlertTypeEnumMap[instance.alertType]!,
      'message': instance.message,
      'is_resolved': instance.isResolved,
      'created_at': const UtcDateTimeConverter().toJson(instance.createdAt),
    };

const _$AlertTypeEnumMap = {
  AlertType.lowFuel: 'low_fuel',
  AlertType.unknown: 'unknown',
};
