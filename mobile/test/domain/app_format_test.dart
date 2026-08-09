import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/time/app_format.dart';
import 'package:mobile/core/time/app_time.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('AppFormat.dateTime', () {
    test('formats an offset-less backend string as local d MMM HH:mm', () {
      final parsed = parseBackendDateTime('2026-08-07T15:44:54.044240');

      // toLocal() depends on the test host's timezone, so assert shape
      // rather than a fixed hour.
      final formatted = AppFormat.dateTime(parsed);
      expect(formatted, matches(RegExp(r'^\d{1,2} \w+\.? \d{2}:\d{2}$')));
    });

    test(
      'formats a Z-suffixed backend string identically to its offset-less twin',
      () {
        final withoutZone = parseBackendDateTime('2026-08-07T15:44:54.044240');
        final withZone = parseBackendDateTime('2026-08-07T15:44:54.044240Z');

        expect(AppFormat.dateTime(withoutZone), AppFormat.dateTime(withZone));
      },
    );
  });

  group('AppFormat.timeAgo bucket boundaries', () {
    final now = DateTime.utc(2026, 8, 7, 12, 0, 0);

    test('under 60 seconds ago is Justo ahora', () {
      final value = now.subtract(const Duration(seconds: 30));
      expect(AppFormat.timeAgo(value, now: now), 'Justo ahora');
    });

    test('5 minutes ago is Hace 5 min', () {
      final value = now.subtract(const Duration(minutes: 5));
      expect(AppFormat.timeAgo(value, now: now), 'Hace 5 min');
    });

    test('59 minutes ago is still in minutes', () {
      final value = now.subtract(const Duration(minutes: 59));
      expect(AppFormat.timeAgo(value, now: now), 'Hace 59 min');
    });

    test('60 minutes ago rolls over to Hace 1 h', () {
      final value = now.subtract(const Duration(minutes: 60));
      expect(AppFormat.timeAgo(value, now: now), 'Hace 1 h');
    });

    test('23 hours ago is still in hours', () {
      final value = now.subtract(const Duration(hours: 23));
      expect(AppFormat.timeAgo(value, now: now), 'Hace 23 h');
    });

    test('24 hours ago rolls over to Hace 1 d', () {
      final value = now.subtract(const Duration(hours: 24));
      expect(AppFormat.timeAgo(value, now: now), 'Hace 1 d');
    });

    test('null instant is Sin datos', () {
      expect(AppFormat.timeAgo(null, now: now), 'Sin datos');
    });
  });

  group('AppFormat.shortAge', () {
    final now = DateTime.utc(2026, 8, 7, 12, 0, 0);

    test('shares timeAgo bucket boundaries without the Hace prefix', () {
      expect(
        AppFormat.shortAge(now.subtract(const Duration(seconds: 30)), now: now),
        'ahora',
      );
      expect(
        AppFormat.shortAge(now.subtract(const Duration(minutes: 59)), now: now),
        '59 min',
      );
      expect(
        AppFormat.shortAge(now.subtract(const Duration(minutes: 60)), now: now),
        '1 h',
      );
      expect(
        AppFormat.shortAge(now.subtract(const Duration(hours: 24)), now: now),
        '1 d',
      );
    });

    test('null instant is an em dash, not "Sin datos" in a metric tile', () {
      expect(AppFormat.shortAge(null, now: now), '—');
    });
  });

  group('AppFormat.clockAndDate', () {
    test('renders time and long date around a middot separator', () {
      final parsed = parseBackendDateTime('2026-08-07T15:44:54.044240');

      // toLocal() depends on the test host's timezone, so assert shape
      // rather than a fixed hour.
      expect(
        AppFormat.clockAndDate(parsed),
        matches(RegExp(r'^\d{2}:\d{2} · \d{2} \w+\.? \d{4}$')),
      );
    });
  });
}
