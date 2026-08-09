import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A [WebSocketChannel] test double confirmed against the installed
/// `web_socket_channel: 3.0.3` API surface: `WebSocketChannel extends
/// StreamChannelMixin` (from `package:stream_channel`, a transitive dep),
/// which implements everything except `stream`/`sink` — so only those plus
/// `protocol`/`closeCode`/`closeReason`/`ready` need overriding here.
///
/// Real Hive deadlocks under `testWidgets`, but there is no such trap with a
/// real socket — the reason this is a fake at all is simply that opening an
/// actual `WebSocketChannel` in a unit test would need a live server.
class FakeWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel();

  final _incoming = StreamController<dynamic>.broadcast();
  final _sink = _FakeWebSocketSink();

  /// The URI the test's injected [WebSocketChannel Function(Uri)] factory
  /// was called with, captured by the factory itself — see
  /// `FakeChannelFactory` below.

  @override
  Stream get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? protocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Future<void> get ready => Future<void>.value();

  /// Simulates an incoming server message.
  void emit(String message) => _incoming.add(message);

  /// Simulates the server closing the connection with [code].
  Future<void> simulateClose(int code) async {
    closeCode = code;
    await _incoming.close();
  }

  /// The code the app side passed to `sink.close(code)` — `null` if the app
  /// never initiated a close on this channel.
  int? get appCloseCode => _sink.closeCode;
}

class _FakeWebSocketSink implements WebSocketSink {
  final _doneCompleter = Completer<void>();
  int? closeCode;
  String? closeReason;

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future close([int? closeCode, String? closeReason]) {
    this.closeCode = closeCode;
    this.closeReason = closeReason;
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
    return Future<void>.value();
  }
}

/// A call-counting `WebSocketChannel Function(Uri)` factory — the injection
/// point [TelemetrySocket] and `telemetrySocketProvider` use to prove WS-1's
/// single-connection guarantee without a real socket.
class FakeChannelFactory {
  int callCount = 0;
  final channels = <FakeWebSocketChannel>[];
  Uri? lastUri;

  FakeWebSocketChannel call(Uri uri) {
    callCount++;
    lastUri = uri;
    final channel = FakeWebSocketChannel();
    channels.add(channel);
    return channel;
  }
}
