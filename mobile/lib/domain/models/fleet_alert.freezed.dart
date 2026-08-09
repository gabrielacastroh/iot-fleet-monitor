// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fleet_alert.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FleetAlert {

 String get id; String get deviceId;@JsonKey(unknownEnumValue: AlertType.unknown) AlertType get alertType; String get message; bool get isResolved;@UtcDateTimeConverter() DateTime get createdAt;
/// Create a copy of FleetAlert
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetAlertCopyWith<FleetAlert> get copyWith => _$FleetAlertCopyWithImpl<FleetAlert>(this as FleetAlert, _$identity);

  /// Serializes this FleetAlert to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FleetAlert&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.alertType, alertType) || other.alertType == alertType)&&(identical(other.message, message) || other.message == message)&&(identical(other.isResolved, isResolved) || other.isResolved == isResolved)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,alertType,message,isResolved,createdAt);

@override
String toString() {
  return 'FleetAlert(id: $id, deviceId: $deviceId, alertType: $alertType, message: $message, isResolved: $isResolved, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FleetAlertCopyWith<$Res>  {
  factory $FleetAlertCopyWith(FleetAlert value, $Res Function(FleetAlert) _then) = _$FleetAlertCopyWithImpl;
@useResult
$Res call({
 String id, String deviceId,@JsonKey(unknownEnumValue: AlertType.unknown) AlertType alertType, String message, bool isResolved,@UtcDateTimeConverter() DateTime createdAt
});




}
/// @nodoc
class _$FleetAlertCopyWithImpl<$Res>
    implements $FleetAlertCopyWith<$Res> {
  _$FleetAlertCopyWithImpl(this._self, this._then);

  final FleetAlert _self;
  final $Res Function(FleetAlert) _then;

/// Create a copy of FleetAlert
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? alertType = null,Object? message = null,Object? isResolved = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,alertType: null == alertType ? _self.alertType : alertType // ignore: cast_nullable_to_non_nullable
as AlertType,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isResolved: null == isResolved ? _self.isResolved : isResolved // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FleetAlert].
extension FleetAlertPatterns on FleetAlert {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FleetAlert value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FleetAlert() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FleetAlert value)  $default,){
final _that = this;
switch (_that) {
case _FleetAlert():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FleetAlert value)?  $default,){
final _that = this;
switch (_that) {
case _FleetAlert() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deviceId, @JsonKey(unknownEnumValue: AlertType.unknown)  AlertType alertType,  String message,  bool isResolved, @UtcDateTimeConverter()  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FleetAlert() when $default != null:
return $default(_that.id,_that.deviceId,_that.alertType,_that.message,_that.isResolved,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deviceId, @JsonKey(unknownEnumValue: AlertType.unknown)  AlertType alertType,  String message,  bool isResolved, @UtcDateTimeConverter()  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FleetAlert():
return $default(_that.id,_that.deviceId,_that.alertType,_that.message,_that.isResolved,_that.createdAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deviceId, @JsonKey(unknownEnumValue: AlertType.unknown)  AlertType alertType,  String message,  bool isResolved, @UtcDateTimeConverter()  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FleetAlert() when $default != null:
return $default(_that.id,_that.deviceId,_that.alertType,_that.message,_that.isResolved,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FleetAlert implements FleetAlert {
  const _FleetAlert({required this.id, required this.deviceId, @JsonKey(unknownEnumValue: AlertType.unknown) required this.alertType, required this.message, required this.isResolved, @UtcDateTimeConverter() required this.createdAt});
  factory _FleetAlert.fromJson(Map<String, dynamic> json) => _$FleetAlertFromJson(json);

@override final  String id;
@override final  String deviceId;
@override@JsonKey(unknownEnumValue: AlertType.unknown) final  AlertType alertType;
@override final  String message;
@override final  bool isResolved;
@override@UtcDateTimeConverter() final  DateTime createdAt;

/// Create a copy of FleetAlert
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetAlertCopyWith<_FleetAlert> get copyWith => __$FleetAlertCopyWithImpl<_FleetAlert>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FleetAlertToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FleetAlert&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.alertType, alertType) || other.alertType == alertType)&&(identical(other.message, message) || other.message == message)&&(identical(other.isResolved, isResolved) || other.isResolved == isResolved)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,alertType,message,isResolved,createdAt);

@override
String toString() {
  return 'FleetAlert(id: $id, deviceId: $deviceId, alertType: $alertType, message: $message, isResolved: $isResolved, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FleetAlertCopyWith<$Res> implements $FleetAlertCopyWith<$Res> {
  factory _$FleetAlertCopyWith(_FleetAlert value, $Res Function(_FleetAlert) _then) = __$FleetAlertCopyWithImpl;
@override @useResult
$Res call({
 String id, String deviceId,@JsonKey(unknownEnumValue: AlertType.unknown) AlertType alertType, String message, bool isResolved,@UtcDateTimeConverter() DateTime createdAt
});




}
/// @nodoc
class __$FleetAlertCopyWithImpl<$Res>
    implements _$FleetAlertCopyWith<$Res> {
  __$FleetAlertCopyWithImpl(this._self, this._then);

  final _FleetAlert _self;
  final $Res Function(_FleetAlert) _then;

/// Create a copy of FleetAlert
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? alertType = null,Object? message = null,Object? isResolved = null,Object? createdAt = null,}) {
  return _then(_FleetAlert(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,alertType: null == alertType ? _self.alertType : alertType // ignore: cast_nullable_to_non_nullable
as AlertType,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isResolved: null == isResolved ? _self.isResolved : isResolved // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
