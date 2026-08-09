import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;
  late ProviderContainer container;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => changes.stream);
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);

    container = ProviderContainer(
      overrides: [connectivityClientProvider.overrideWithValue(connectivity)],
    );
    addTearDown(container.dispose);
    addTearDown(changes.close);
  });

  test('OFF-1: interface down flips state to offline', () async {
    container.listen(connectivityProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(connectivityProvider), isTrue);

    changes.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(connectivityProvider), isFalse);
  });

  test(
    'a reachability report from the error interceptor also flips state offline',
    () async {
      container.listen(connectivityProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(connectivityProvider), isTrue);

      container.read(connectivityProvider.notifier).reportReachability(false);

      expect(container.read(connectivityProvider), isFalse);
    },
  );

  test(
    'online requires both the interface up and the last request reachable',
    () async {
      container.listen(connectivityProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      container.read(connectivityProvider.notifier).reportReachability(false);
      expect(container.read(connectivityProvider), isFalse);

      changes.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      // Interface is up again, but the last request still failed.
      expect(container.read(connectivityProvider), isFalse);

      container.read(connectivityProvider.notifier).reportReachability(true);
      expect(container.read(connectivityProvider), isTrue);
    },
  );
}
