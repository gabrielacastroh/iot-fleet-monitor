import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/rules/time_ago.dart';

void main() {
  final now = DateTime.utc(2026, 8, 7, 12, 0, 0);

  test('under 60 seconds ago is Justo ahora', () {
    expect(
      timeAgo(now.subtract(const Duration(seconds: 30)), now: now),
      'Justo ahora',
    );
  });

  test('5 minutes ago is Hace 5 min', () {
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      'Hace 5 min',
    );
  });

  test('59 minutes ago is still in minutes', () {
    expect(
      timeAgo(now.subtract(const Duration(minutes: 59)), now: now),
      'Hace 59 min',
    );
  });

  test('60 minutes ago rolls over to Hace 1 h', () {
    expect(
      timeAgo(now.subtract(const Duration(minutes: 60)), now: now),
      'Hace 1 h',
    );
  });

  test('23 hours ago is still in hours', () {
    expect(
      timeAgo(now.subtract(const Duration(hours: 23)), now: now),
      'Hace 23 h',
    );
  });

  test('24 hours ago rolls over to Hace 1 d', () {
    expect(
      timeAgo(now.subtract(const Duration(hours: 24)), now: now),
      'Hace 1 d',
    );
  });

  test('a null instant is Sin datos', () {
    expect(timeAgo(null, now: now), 'Sin datos');
  });
}
