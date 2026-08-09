import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/date_range.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mobile/state/telemetry_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

TelemetryReading _reading(String id) => TelemetryReading(
  id: id,
  deviceId: 'd1',
  latitude: 0,
  longitude: 0,
  speed: 10,
  fuelLevel: 90,
  temperature: 20,
  recordedAt: DateTime.utc(2026),
);

void main() {
  late _MockTelemetryRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockTelemetryRepository();
    container = ProviderContainer(
      overrides: [
        telemetryRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'VDET-3: the default 7-day range requests an exact 7-day span ending now',
    () async {
      when(
        () => repository.fetchHistory(
          deviceId: any(named: 'deviceId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_reading('t1')]);

      final now = DateTime.utc(2026, 8, 8, 12);
      final range = rangeFromDays(defaultRangeDays, now: now);
      final query = HistoryQuery(
        deviceId: 'd1',
        startDate: range.startDate,
        endDate: range.endDate,
      );

      final result = await container.read(
        telemetryHistoryProvider(query).future,
      );

      expect(result, hasLength(1));
      final captured = verify(
        () => repository.fetchHistory(
          deviceId: 'd1',
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
          limit: any(named: 'limit'),
        ),
      ).captured;
      final start = captured[0] as DateTime;
      final end = captured[1] as DateTime;
      expect(end.difference(start), const Duration(days: 7));
    },
  );

  test('a new range (different family key) re-fetches', () async {
    when(
      () => repository.fetchHistory(
        deviceId: any(named: 'deviceId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [_reading('t1')]);

    final now = DateTime.utc(2026, 8, 8, 12);
    final range7 = rangeFromDays(7, now: now);
    final range30 = rangeFromDays(30, now: now);

    await container.read(
      telemetryHistoryProvider(
        HistoryQuery(
          deviceId: 'd1',
          startDate: range7.startDate,
          endDate: range7.endDate,
        ),
      ).future,
    );
    await container.read(
      telemetryHistoryProvider(
        HistoryQuery(
          deviceId: 'd1',
          startDate: range30.startDate,
          endDate: range30.endDate,
        ),
      ).future,
    );

    verify(
      () => repository.fetchHistory(
        deviceId: any(named: 'deviceId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        limit: any(named: 'limit'),
      ),
    ).called(2);
  });
}
