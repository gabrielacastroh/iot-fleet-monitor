import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/state/alerts_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockAlertRepository extends Mock implements AlertRepository {}

FleetAlert _alert(String id, {bool isResolved = false}) => FleetAlert(
  id: id,
  deviceId: 'd1',
  alertType: AlertType.lowFuel,
  message: 'Combustible bajo',
  isResolved: isResolved,
  createdAt: DateTime.utc(2026, 8, 1),
);

void main() {
  late _MockAlertRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockAlertRepository();
    container = ProviderContainer(
      overrides: [
        alertRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'ALT-3: resolve removes the alert optimistically before the PATCH response returns',
    () async {
      when(() => repository.peekCache()).thenReturn(null);
      when(
        () => repository.fetchAndCache(),
      ).thenAnswer((_) async => [_alert('a1'), _alert('a2')]);
      final completer = Completer<FleetAlert>();
      when(() => repository.resolve('a1')).thenAnswer((_) => completer.future);

      await container.read(alertsProvider.future);

      final resolveFuture = container
          .read(alertsProvider.notifier)
          .resolve('a1');
      // The PATCH is still in flight (the completer hasn't fired), but the
      // optimistic removal must already be visible.
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(alertsProvider).valueOrNull?.value.map((a) => a.id),
        ['a2'],
      );

      completer.complete(_alert('a1', isResolved: true));
      await resolveFuture;
      expect(
        container.read(alertsProvider).valueOrNull?.value.map((a) => a.id),
        ['a2'],
      );
    },
  );

  test(
    'ALT-4: a PATCH failure rolls back the optimistic removal and rethrows',
    () async {
      when(() => repository.peekCache()).thenReturn(null);
      when(
        () => repository.fetchAndCache(),
      ).thenAnswer((_) async => [_alert('a1')]);
      when(() => repository.resolve('a1')).thenThrow(const NetworkFailure());

      await container.read(alertsProvider.future);

      await expectLater(
        container.read(alertsProvider.notifier).resolve('a1'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(
        container.read(alertsProvider).valueOrNull?.value.map((a) => a.id),
        ['a1'],
      );
    },
  );

  test(
    'resolve still calls the PATCH for an alert absent from the current open list',
    () async {
      when(() => repository.peekCache()).thenReturn(null);
      when(
        () => repository.fetchAndCache(),
      ).thenAnswer((_) async => [_alert('a1')]);
      when(
        () => repository.resolve('other'),
      ).thenAnswer((_) async => _alert('other', isResolved: true));

      await container.read(alertsProvider.future);
      await container.read(alertsProvider.notifier).resolve('other');

      verify(() => repository.resolve('other')).called(1);
      expect(
        container.read(alertsProvider).valueOrNull?.value.map((a) => a.id),
        ['a1'],
      );
    },
  );
}
