import 'package:intl/intl.dart';

import '../../domain/rules/time_ago.dart' as rules;

/// Local rendering of the app's UTC domain [DateTime]s. `.toLocal()` happens
/// only in this file — everywhere else stays UTC (`app_time.dart`).
class AppFormat {
  const AppFormat._();

  static final DateFormat _dateTimeFormat = DateFormat('d MMM HH:mm', 'es');
  static final DateFormat _clockFormat = DateFormat('HH:mm', 'es');
  static final DateFormat _longDateFormat = DateFormat('dd MMM y', 'es');
  static final DateFormat _dayMonthFormat = DateFormat('d MMM', 'es');

  /// Renders a UTC instant in the device's local time, e.g. "7 ago. 15:44".
  static String dateTime(DateTime value) =>
      _dateTimeFormat.format(value.toLocal());

  /// The vehicle detail header's exact timestamp, e.g. "08:50 · 07 may 2025".
  static String clockAndDate(DateTime value) {
    final local = value.toLocal();
    return '${_clockFormat.format(local)} · ${_longDateFormat.format(local)}';
  }

  /// Chart axis ticks, e.g. "3 may".
  static String dayMonth(DateTime value) =>
      _dayMonthFormat.format(value.toLocal());

  /// Chart axis ticks for a short trailing window, e.g. "14:32".
  static String clock(DateTime value) => _clockFormat.format(value.toLocal());

  /// [rules.timeAgo] without its "Hace" prefix — see `shortAge`.
  static String shortAge(DateTime? value, {DateTime? now}) =>
      rules.shortAge(value, now: now);

  /// Relative-time buckets — delegates to `domain/rules/time_ago.dart`,
  /// the single source of truth (T2.1.7). `now` is injectable for
  /// deterministic tests.
  static String timeAgo(DateTime? value, {DateTime? now}) =>
      rules.timeAgo(value, now: now);
}
