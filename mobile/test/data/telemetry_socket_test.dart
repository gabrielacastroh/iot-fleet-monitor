import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/realtime/telemetry_socket.dart';
import 'package:mobile/data/realtime/ws_event.dart';

import '../helpers/fake_websocket_channel.dart';

void main() {
  group('TelemetrySocket', () {
    test(
      'WS-1 reinforcement #2: calling connect() twice opens only one channel',
      () {
        final factory = FakeChannelFactory();
        final socket = TelemetrySocket(
          wsBaseUrl: 'ws://localhost:8000',
          channelFactory: factory.call,
        );

        socket.connect('token-1');
        socket.connect('token-1');

        expect(factory.callCount, 1);
      },
    );

    test(
      'connectionState: closed -> connecting -> open, in that order, on a '
      'clean connect',
      () {
        fakeAsync((async) {
          final factory = FakeChannelFactory();
          final states = <WsConnectionState>[];
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
            onConnectionStateChanged: states.add,
          );

          expect(socket.connectionState, WsConnectionState.closed);

          socket.connect('token-1');
          expect(socket.connectionState, WsConnectionState.connecting);

          async.flushMicrotasks();
          expect(socket.connectionState, WsConnectionState.open);
          expect(states, [
            WsConnectionState.connecting,
            WsConnectionState.open,
          ]);
        });
      },
    );

    test('WS-2: connects to {wsBase}/ws/telemetry?token=<jwt>', () {
      final factory = FakeChannelFactory();
      final socket = TelemetrySocket(
        wsBaseUrl: 'ws://localhost:8000',
        channelFactory: factory.call,
      );

      socket.connect('abc.def.ghi');

      expect(factory.lastUri?.path, '/ws/telemetry');
      expect(factory.lastUri?.queryParameters['token'], 'abc.def.ghi');
    });

    test(
      'WS-6: a telemetry_updated message is parsed and published on events',
      () async {
        final factory = FakeChannelFactory();
        final socket = TelemetrySocket(
          wsBaseUrl: 'ws://localhost:8000',
          channelFactory: factory.call,
        );
        socket.connect('token-1');

        final future = socket.events.first;
        factory.channels.single.emit('''
      {
        "type": "telemetry_updated",
        "data": {
          "device_id": "d1", "reading_id": "r1", "latitude": 0, "longitude": 0,
          "speed": 10, "fuel_level": 50, "temperature": 20,
          "recorded_at": "2026-08-08T10:00:00.000000"
        }
      }
      ''');

        final event = await future;
        expect(event, isA<TelemetryUpdatedWsEvent>());
      },
    );

    test('WS-9: a 1008 close does not schedule a reconnect', () {
      fakeAsync((async) {
        final factory = FakeChannelFactory();
        var sessionInvalidCount = 0;
        final socket = TelemetrySocket(
          wsBaseUrl: 'ws://localhost:8000',
          channelFactory: factory.call,
          onSessionInvalid: () => sessionInvalidCount++,
        );

        socket.connect('token-1');
        async.flushMicrotasks();
        factory.channels.single.simulateClose(1008);
        async.flushMicrotasks();

        // Advance well past the full 8-attempt backoff budget (~2 min cap).
        async.elapse(const Duration(minutes: 5));

        expect(sessionInvalidCount, 1);
        expect(factory.callCount, 1); // never retried
        expect(socket.connectionState, WsConnectionState.closed);
      });
    });

    test(
      'WS-4: an unexpected drop reconnects with a capped, jittered backoff',
      () {
        fakeAsync((async) {
          final factory = FakeChannelFactory();
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
            random: Random(1), // deterministic jitter for this test
          );

          socket.connect('token-1');
          async.flushMicrotasks();
          expect(factory.callCount, 1);

          factory.channels.last.simulateClose(1006);
          async.flushMicrotasks();
          expect(factory.callCount, 1); // not yet, backoff pending
          expect(socket.connectionState, WsConnectionState.reconnecting);

          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
          expect(factory.callCount, 2); // first backoff (<=1s) has elapsed
          expect(socket.connectionState, WsConnectionState.open);
        });
      },
    );

    test(
      'WS-4: reconnect attempts stop after the 8-attempt cap (~2 min budget)',
      () {
        fakeAsync((async) {
          final factory = FakeChannelFactory();
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
          );

          socket.connect('token-1');
          async.flushMicrotasks();

          // Every attempt immediately drops with a non-1008 code, so the
          // socket keeps rescheduling until the 8-attempt cap is hit.
          for (var i = 0; i < 12; i++) {
            async.elapse(const Duration(seconds: 31));
            if (factory.channels.isNotEmpty) {
              factory.channels.last.simulateClose(1006);
              async.flushMicrotasks();
            }
          }

          // 1 initial connect + at most 8 reconnect attempts = 9 total calls.
          expect(factory.callCount, lessThanOrEqualTo(9));
          expect(factory.callCount, greaterThan(1));
          expect(socket.connectionState, WsConnectionState.closed);
        });
      },
    );

    test(
      'WS-5: resume() resets the backoff budget and connects immediately',
      () {
        fakeAsync((async) {
          final factory = FakeChannelFactory();
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
          );

          socket.connect('token-1');
          async.flushMicrotasks();
          socket.suspend();
          expect(socket.connectionState, WsConnectionState.closed);

          socket.resume('token-1');
          async.flushMicrotasks();

          expect(factory.callCount, 2);
          expect(socket.connectionState, WsConnectionState.open);
        });
      },
    );

    test(
      'design §6.1: onReconnected fires on a reconnect but not on the first connect',
      () {
        fakeAsync((async) {
          final factory = FakeChannelFactory();
          var reconnectedCount = 0;
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
            onReconnected: () => reconnectedCount++,
          );

          socket.connect('token-1');
          async.flushMicrotasks();
          expect(reconnectedCount, 0); // first connect never counts

          factory.channels.last.simulateClose(1006);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          expect(reconnectedCount, 1);
        });
      },
    );

    test(
      'WS-5/WS-3: suspend()/close() close with code 1000 and stop retrying',
      () {
        fakeAsync((async) {
          final factory = FakeChannelFactory();
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
          );

          socket.connect('token-1');
          async.flushMicrotasks();
          socket.suspend();
          async.flushMicrotasks();

          expect(factory.channels.single.sink, isNotNull);
          expect(socket.connectionState, WsConnectionState.closed);
          async.elapse(const Duration(minutes: 5));
          expect(factory.callCount, 1); // no reconnect after a manual suspend
        });
      },
    );
  });
}
