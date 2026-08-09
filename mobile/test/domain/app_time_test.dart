import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/time/app_time.dart';

void main() {
  group('parseBackendDateTime', () {
    // Empirically verified against the real dev backend (SQLite via
    // aiosqlite): `DateTime(timezone=True)` columns serialize with NO
    // offset in dev mode (e.g. "2026-08-07T15:44:54.044240"), even though
    // the column is declared tz-aware. Postgres would emit "+00:00".
    // Both shapes must resolve to the same instant.
    test('an offset-less ISO string is treated as UTC, not local', () {
      final parsed = parseBackendDateTime('2026-08-07T15:44:54.044240');

      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 15);
      expect(parsed.minute, 44);
    });

    test('a Z-suffixed ISO string is treated as UTC', () {
      final parsed = parseBackendDateTime('2026-08-07T15:44:54.044240Z');

      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 15);
    });

    test('a +00:00-suffixed ISO string is treated as UTC', () {
      final parsed = parseBackendDateTime('2026-08-07T15:44:54.044240+00:00');

      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 15);
    });

    test(
      'an offset-less string and its Z-suffixed twin parse to the same instant',
      () {
        final withoutZone = parseBackendDateTime('2026-08-07T15:44:54.044240');
        final withZone = parseBackendDateTime('2026-08-07T15:44:54.044240Z');

        expect(withoutZone, withZone);
      },
    );

    test('a non-UTC offset is normalized to UTC', () {
      final parsed = parseBackendDateTime('2026-08-07T10:44:54.000000-05:00');

      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 15);
    });
  });

  group('serializeUtc', () {
    test('serializes a DateTime as a UTC ISO-8601 string', () {
      final value = DateTime.utc(2026, 8, 7, 15, 44, 54);

      expect(serializeUtc(value), '2026-08-07T15:44:54.000Z');
    });

    test('converts a local DateTime to UTC before serializing', () {
      final local = DateTime.utc(2026, 8, 7, 15, 44, 54).toLocal();

      expect(serializeUtc(local), '2026-08-07T15:44:54.000Z');
    });
  });
}
