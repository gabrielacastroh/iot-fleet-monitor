import 'package:json_annotation/json_annotation.dart';

import '../../core/time/app_time.dart';

/// Wraps [parseBackendDateTime]/[serializeUtc] (T0.3.4) as a
/// [JsonConverter] so a model field only needs `@UtcDateTimeConverter()`
/// instead of repeating the `@JsonKey(fromJson:, toJson:)` pair (design §4).
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => parseBackendDateTime(json);

  @override
  String toJson(DateTime object) => serializeUtc(object);
}

/// JSON `0` decodes to `int` in Dart and would throw on a `double` field.
/// Applied to every `double` field across the domain models (design §4) —
/// one shared converter removes an entire crash class.
class LooseDoubleConverter implements JsonConverter<double, num> {
  const LooseDoubleConverter();

  @override
  double fromJson(num json) => json.toDouble();

  @override
  num toJson(double object) => object;
}
