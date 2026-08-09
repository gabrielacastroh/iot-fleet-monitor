import '../../core/time/app_time.dart';

/// The JSON wrapper every cached Hive value is stored as: `jsonEncode(
/// CacheEntry(cachedAt, payload).toJson())` (design §5.1). [payload] is
/// already a JSON-encodable structure — typically a model's own `toJson()`.
class CacheEntry {
  const CacheEntry({required this.cachedAt, required this.payload});

  final DateTime cachedAt;
  final Object? payload;

  Map<String, dynamic> toJson() => {
    'cached_at': serializeUtc(cachedAt),
    'payload': payload,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    cachedAt: parseBackendDateTime(json['cached_at'] as String),
    payload: json['payload'],
  );
}
