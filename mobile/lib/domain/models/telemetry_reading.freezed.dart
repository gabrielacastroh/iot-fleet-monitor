// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telemetry_reading.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TelemetryReading {

 String get id; String get deviceId;@LooseDoubleConverter() double get latitude;@LooseDoubleConverter() double get longitude;@LooseDoubleConverter() double get speed;@LooseDoubleConverter() double get fuelLevel;@LooseDoubleConverter() double get temperature;@UtcDateTimeConverter() DateTime get recordedAt;
/// Create a copy of TelemetryReading
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelemetryReadingCopyWith<TelemetryReading> get copyWith => _$TelemetryReadingCopyWithImpl<TelemetryReading>(this as TelemetryReading, _$identity);

  /// Serializes this TelemetryReading to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryReading&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.fuelLevel, fuelLevel) || other.fuelLevel == fuelLevel)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,latitude,longitude,speed,fuelLevel,temperature,recordedAt);

@override
String toString() {
  return 'TelemetryReading(id: $id, deviceId: $deviceId, latitude: $latitude, longitude: $longitude, speed: $speed, fuelLevel: $fuelLevel, temperature: $temperature, recordedAt: $recordedAt)';
}


}

/// @nodoc
abstract mixin class $TelemetryReadingCopyWith<$Res>  {
  factory $TelemetryReadingCopyWith(TelemetryReading value, $Res Function(TelemetryReading) _then) = _$TelemetryReadingCopyWithImpl;
@useResult
$Res call({
 String id, String deviceId,@LooseDoubleConverter() double latitude,@LooseDoubleConverter() double longitude,@LooseDoubleConverter() double speed,@LooseDoubleConverter() double fuelLevel,@LooseDoubleConverter() double temperature,@UtcDateTimeConverter() DateTime recordedAt
});




}
/// @nodoc
class _$TelemetryReadingCopyWithImpl<$Res>
    implements $TelemetryReadingCopyWith<$Res> {
  _$TelemetryReadingCopyWithImpl(this._self, this._then);

  final TelemetryReading _self;
  final $Res Function(TelemetryReading) _then;

/// Create a copy of TelemetryReading
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? latitude = null,Object? longitude = null,Object? speed = null,Object? fuelLevel = null,Object? temperature = null,Object? recordedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,fuelLevel: null == fuelLevel ? _self.fuelLevel : fuelLevel // ignore: cast_nullable_to_non_nullable
as double,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TelemetryReading].
extension TelemetryReadingPatterns on TelemetryReading {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TelemetryReading value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TelemetryReading() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TelemetryReading value)  $default,){
final _that = this;
switch (_that) {
case _TelemetryReading():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TelemetryReading value)?  $default,){
final _that = this;
switch (_that) {
case _TelemetryReading() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deviceId, @LooseDoubleConverter()  double latitude, @LooseDoubleConverter()  double longitude, @LooseDoubleConverter()  double speed, @LooseDoubleConverter()  double fuelLevel, @LooseDoubleConverter()  double temperature, @UtcDateTimeConverter()  DateTime recordedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TelemetryReading() when $default != null:
return $default(_that.id,_that.deviceId,_that.latitude,_that.longitude,_that.speed,_that.fuelLevel,_that.temperature,_that.recordedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deviceId, @LooseDoubleConverter()  double latitude, @LooseDoubleConverter()  double longitude, @LooseDoubleConverter()  double speed, @LooseDoubleConverter()  double fuelLevel, @LooseDoubleConverter()  double temperature, @UtcDateTimeConverter()  DateTime recordedAt)  $default,) {final _that = this;
switch (_that) {
case _TelemetryReading():
return $default(_that.id,_that.deviceId,_that.latitude,_that.longitude,_that.speed,_that.fuelLevel,_that.temperature,_that.recordedAt);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deviceId, @LooseDoubleConverter()  double latitude, @LooseDoubleConverter()  double longitude, @LooseDoubleConverter()  double speed, @LooseDoubleConverter()  double fuelLevel, @LooseDoubleConverter()  double temperature, @UtcDateTimeConverter()  DateTime recordedAt)?  $default,) {final _that = this;
switch (_that) {
case _TelemetryReading() when $default != null:
return $default(_that.id,_that.deviceId,_that.latitude,_that.longitude,_that.speed,_that.fuelLevel,_that.temperature,_that.recordedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TelemetryReading implements TelemetryReading {
  const _TelemetryReading({required this.id, required this.deviceId, @LooseDoubleConverter() required this.latitude, @LooseDoubleConverter() required this.longitude, @LooseDoubleConverter() required this.speed, @LooseDoubleConverter() required this.fuelLevel, @LooseDoubleConverter() required this.temperature, @UtcDateTimeConverter() required this.recordedAt});
  factory _TelemetryReading.fromJson(Map<String, dynamic> json) => _$TelemetryReadingFromJson(json);

@override final  String id;
@override final  String deviceId;
@override@LooseDoubleConverter() final  double latitude;
@override@LooseDoubleConverter() final  double longitude;
@override@LooseDoubleConverter() final  double speed;
@override@LooseDoubleConverter() final  double fuelLevel;
@override@LooseDoubleConverter() final  double temperature;
@override@UtcDateTimeConverter() final  DateTime recordedAt;

/// Create a copy of TelemetryReading
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TelemetryReadingCopyWith<_TelemetryReading> get copyWith => __$TelemetryReadingCopyWithImpl<_TelemetryReading>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TelemetryReadingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TelemetryReading&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.fuelLevel, fuelLevel) || other.fuelLevel == fuelLevel)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,latitude,longitude,speed,fuelLevel,temperature,recordedAt);

@override
String toString() {
  return 'TelemetryReading(id: $id, deviceId: $deviceId, latitude: $latitude, longitude: $longitude, speed: $speed, fuelLevel: $fuelLevel, temperature: $temperature, recordedAt: $recordedAt)';
}


}

/// @nodoc
abstract mixin class _$TelemetryReadingCopyWith<$Res> implements $TelemetryReadingCopyWith<$Res> {
  factory _$TelemetryReadingCopyWith(_TelemetryReading value, $Res Function(_TelemetryReading) _then) = __$TelemetryReadingCopyWithImpl;
@override @useResult
$Res call({
 String id, String deviceId,@LooseDoubleConverter() double latitude,@LooseDoubleConverter() double longitude,@LooseDoubleConverter() double speed,@LooseDoubleConverter() double fuelLevel,@LooseDoubleConverter() double temperature,@UtcDateTimeConverter() DateTime recordedAt
});




}
/// @nodoc
class __$TelemetryReadingCopyWithImpl<$Res>
    implements _$TelemetryReadingCopyWith<$Res> {
  __$TelemetryReadingCopyWithImpl(this._self, this._then);

  final _TelemetryReading _self;
  final $Res Function(_TelemetryReading) _then;

/// Create a copy of TelemetryReading
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? latitude = null,Object? longitude = null,Object? speed = null,Object? fuelLevel = null,Object? temperature = null,Object? recordedAt = null,}) {
  return _then(_TelemetryReading(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,fuelLevel: null == fuelLevel ? _self.fuelLevel : fuelLevel // ignore: cast_nullable_to_non_nullable
as double,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
