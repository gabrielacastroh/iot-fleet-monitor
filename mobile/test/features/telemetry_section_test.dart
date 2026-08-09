import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/features/vehicles/widgets/telemetry_section.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

TelemetryReading _reading(DateTime recordedAt) => TelemetryReading(
  id: 't-${recordedAt.millisecondsSinceEpoch}',
  deviceId: 'd1',
  latitude: 1,
  longitude: 1,
  speed: 30,
  fuelLevel: 70,
  temperature: 21,
  recordedAt: recordedAt,
);

Future<_MockTelemetryRepository> _pump(
  WidgetTester tester, {
  Object? error,
  List<TelemetryReading>? readings,
}) async {
  pinPhoneViewport(tester);
  final repository = _MockTelemetryRepository();
  if (error != null) {
    when(
      () => repository.fetchHistory(
        deviceId: any(named: 'deviceId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(error);
  } else {
    when(
      () => repository.fetchHistory(
        deviceId: any(named: 'deviceId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => readings ?? const []);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        telemetryRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          // The section lives inside the detail screen's scroll view, so
          // that is the only shape its own layout has to hold up under.
          body: ListView(
            children: const [TelemetrySection(deviceId: 'd1')],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('VDET-3: the default range requests a 7-day span', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      readings: [_reading(DateTime.utc(2026, 8, 1))],
    );

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
  });

  testWidgets('VDET-6: an empty range shows the explicit empty copy', (
    tester,
  ) async {
    await _pump(tester, readings: const []);

    expect(find.text(AppStrings.noReadingsInRangeMessage), findsWidgets);
  });

  testWidgets(
    'OFF-3b: offline with no prior fetch shows the offline-no-cache copy, not a hung spinner',
    (tester) async {
      await _pump(tester, error: const NetworkFailure());

      expect(find.text(AppStrings.offlineNoCacheMessage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('a date-range change re-fetches', (tester) async {
    final repository = await _pump(
      tester,
      readings: [_reading(DateTime.utc(2026, 8, 1))],
    );

    await tester.tap(find.text('30d'));
    await tester.pumpAndSettle();

    verify(
      () => repository.fetchHistory(
        deviceId: any(named: 'deviceId'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        limit: any(named: 'limit'),
      ),
    ).called(2);
  });

  testWidgets('VDET-5: the route map ships with the charts, not behind a tab', (
    tester,
  ) async {
    await _pump(tester, readings: [_reading(DateTime.utc(2026, 8, 1))]);

    expect(find.text(AppStrings.chartSpeedTitle), findsOneWidget);
    expect(find.text(AppStrings.chartFuelTitle), findsOneWidget);
    expect(find.text(AppStrings.chartTemperatureTitle), findsOneWidget);
    expect(find.text(AppStrings.routeMapTitle), findsWidgets);
  });
}
