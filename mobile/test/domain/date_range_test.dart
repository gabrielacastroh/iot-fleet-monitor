import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/rules/date_range.dart';

void main() {
  test('defaultRangeDays is 7 (VDET-3)', () {
    expect(defaultRangeDays, 7);
  });

  test('the range spans exactly `days` * 24h, ending now', () {
    final now = DateTime.utc(2026, 8, 7, 12, 30, 15);

    final range = rangeFromDays(7, now: now);

    expect(range.endDate.difference(range.startDate), const Duration(days: 7));
  });

  test('the end is snapped up to the next whole minute', () {
    final now = DateTime.utc(2026, 8, 7, 12, 30, 15, 500);

    final range = rangeFromDays(7, now: now);

    expect(range.endDate.second, 0);
    expect(range.endDate.millisecond, 0);
    expect(range.endDate.isAfter(now), isTrue);
  });

  test('an exact-minute instant is not rounded further forward', () {
    final now = DateTime.utc(2026, 8, 7, 12, 30);

    final range = rangeFromDays(1, now: now);

    expect(range.endDate, now);
  });
}
