import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/converters.dart';

void main() {
  group('UtcDateTimeConverter', () {
    const converter = UtcDateTimeConverter();

    test('parses an offset-less backend string as UTC', () {
      final parsed = converter.fromJson('2026-08-07T15:44:54.044240');

      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 15);
    });

    test('parses a Z-suffixed string as UTC', () {
      final parsed = converter.fromJson('2026-08-07T15:44:54.044240Z');

      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 15);
    });

    test('serializes back to a UTC ISO-8601 string', () {
      final value = DateTime.utc(2026, 8, 7, 15, 44, 54);

      expect(converter.toJson(value), value.toIso8601String());
    });
  });

  group('LooseDoubleConverter', () {
    const converter = LooseDoubleConverter();

    test(
      'converts an int JSON value to double (the crash class this exists for)',
      () {
        expect(converter.fromJson(0), 0.0);
        expect(converter.fromJson(42), 42.0);
      },
    );

    test('passes a double JSON value through unchanged', () {
      expect(converter.fromJson(3.5), 3.5);
    });

    test('toJson passes the double straight through', () {
      expect(converter.toJson(12.5), 12.5);
    });
  });
}
