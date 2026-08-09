/// Backend datetimes are ISO-8601 but the dev SQLite path can emit them
/// without an offset even though the column is declared `DateTime(timezone=True)`
/// (SQLite has no timezone type). Postgres emits "+00:00". Verified
/// empirically against the running dev backend: an offset-less string is
/// UTC by construction (`server_default=func.now()`), so this assumes UTC
/// rather than letting `DateTime.parse` assume the device's local zone.
DateTime parseBackendDateTime(String value) {
  final hasZone =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
  return DateTime.parse(hasZone ? value : '${value}Z').toUtc();
}

/// Serializes a [DateTime] as a UTC ISO-8601 string for outgoing query
/// params (`start_date`/`end_date`). Every `DateTime` in the domain and
/// cache layers is UTC; `.toLocal()` happens only in `app_format.dart`.
String serializeUtc(DateTime value) => value.toUtc().toIso8601String();
