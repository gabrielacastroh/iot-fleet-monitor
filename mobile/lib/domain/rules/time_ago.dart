/// Relative-time buckets for feeds, port of the web's `timeAgo()`
/// (`frontend/src/lib/fleet.ts:151-160`). The single source of truth —
/// `core/time/app_format.dart`'s `AppFormat.timeAgo` delegates here.
/// [now] is injectable for deterministic tests.
String timeAgo(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Sin datos';
  final reference = now ?? DateTime.now().toUtc();
  final diff = reference.toUtc().difference(value.toUtc());

  if (diff.inSeconds < 60) return 'Justo ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  return 'Hace ${diff.inDays} d';
}

/// The same buckets as [timeAgo] without the "Hace" prefix, for metric
/// tiles where the label ("Desde última señal") already says what the
/// number measures. Never derive this by trimming [timeAgo]'s output —
/// the prefix is copy, not structure.
String shortAge(DateTime? value, {DateTime? now}) {
  if (value == null) return '—';
  final reference = now ?? DateTime.now().toUtc();
  final diff = reference.toUtc().difference(value.toUtc());

  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}
