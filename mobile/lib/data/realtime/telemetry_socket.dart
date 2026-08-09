import 'dart:async';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_event.dart';

/// The 1008 (`WS_1008_POLICY_VIOLATION`) close code the backend sends when
/// the token is missing/invalid/expired (`backend/app/websocket/router.py`).
/// WS-9: terminal, never retried.
const _sessionInvalidCloseCode = 1008;

/// Normal closure, used by [TelemetrySocket.suspend]/[TelemetrySocket.close]
/// (design §6.1's lifecycle section) — a clean stop, not a drop.
const _normalCloseCode = 1000;

/// design §6.1 WS-4: base 1s, cap 30s, max 8 attempts (~2 min).
const _baseBackoff = Duration(seconds: 1);
const _capBackoff = Duration(seconds: 30);
const _maxReconnectAttempts = 8;

/// [TelemetrySocket]'s real connection lifecycle, surfaced via
/// [TelemetrySocket.onConnectionStateChanged] — distinct from
/// `connectivityProvider` (device network reachability). `closed` covers
/// both "never connected yet" and "gave up/stopped on purpose"; there is no
/// separate terminal-vs-idle state because no caller has needed to tell
/// them apart.
enum WsConnectionState { connecting, open, reconnecting, closed }

/// Owns exactly one [WebSocketChannel] for the app's authenticated
/// lifetime (spec WS-1). This class is the mechanism, not the guarantee —
/// the guarantee is structural, coming from [telemetrySocketProvider] being
/// a single `keepAlive` provider (design §6.1); this class only adds the
/// re-entrancy guard so even a direct double-call to [connect] can't open
/// two channels.
///
/// [channelFactory] defaults to [WebSocketChannel.connect] and exists so a
/// test can inject a call-counting fake and prove the single-connection
/// guarantee without a real socket.
class TelemetrySocket {
  // The external param names (public API) intentionally differ from the
  // private field names they back, so `prefer_initializing_formals`'s
  // suggestion doesn't apply here — a private initializing formal can't be
  // called by name from outside this library.
  TelemetrySocket({
    required String wsBaseUrl,
    WebSocketChannel Function(Uri uri) channelFactory =
        WebSocketChannel.connect,
    this.onSessionInvalid,
    this.onReconnected,
    this.onConnectionStateChanged,
    math.Random? random,
  }) : _wsBaseUrl = wsBaseUrl, // ignore: prefer_initializing_formals
       _channelFactory = channelFactory, // ignore: prefer_initializing_formals
       _random = random ?? math.Random();

  final String _wsBaseUrl;
  final WebSocketChannel Function(Uri uri) _channelFactory;
  final math.Random _random;

  /// WS-9: the socket was closed with code 1008 — the caller must treat the
  /// session as invalid (same teardown as AUTH-9).
  final void Function()? onSessionInvalid;

  /// design §6.1: fired only when a successful [connect] follows a *prior*
  /// successful connect (never on the first connect) — the "invalidate on
  /// reconnect, not first connect" cache-gap-fill rule.
  final void Function()? onReconnected;

  /// Fired on every [WsConnectionState] transition — the real socket
  /// lifecycle, for UI that wants to show it (e.g. diagnostics), as opposed
  /// to `connectivityProvider`'s device-network signal.
  final void Function(WsConnectionState)? onConnectionStateChanged;

  final _controller = StreamController<WsEvent>.broadcast();

  /// The single fan-out every provider/screen listens to.
  Stream<WsEvent> get events => _controller.stream;

  WebSocketChannel? _channel;
  bool _connecting = false;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _hasConnectedOnce = false;
  bool _stopped = true;
  String? _token;

  /// Matches [_stopped]'s `true` pre-connect default — no attempt has been
  /// made yet.
  WsConnectionState _state = WsConnectionState.closed;

  /// Synchronous read of the current connection lifecycle state, for
  /// seeding Riverpod state at provider build time.
  WsConnectionState get connectionState => _state;

  void _setState(WsConnectionState next) {
    _state = next;
    // Deferred one microtask turn, deliberately: the real (non-test)
    // `telemetrySocketProvider` wiring calls `connect()` synchronously from
    // inside its own Riverpod `build()` (realtime_provider.dart) — and
    // `forceLogout()`/`AppShell` can each be the first caller to trigger
    // that build. A synchronous callback here would try to write
    // `wsConnectionStateProvider`'s state while `telemetrySocketProvider`
    // itself is still building, which Riverpod forbids ("Providers are not
    // allowed to modify other providers during their initialization") —
    // confirmed by a real crash in `logout_test.dart` before this existed.
    // `connectionState` above stays synchronous; only the notification is
    // delayed, so by the time it fires the triggering build has returned.
    final callback = onConnectionStateChanged;
    if (callback != null) scheduleMicrotask(() => callback(next));
  }

  /// Opens the single connection at `{wsBase}/ws/telemetry?token=...`
  /// (WS-2). No-op if a channel already exists or a connect attempt is in
  /// flight — the re-entrancy guard design §6.1 calls out explicitly.
  void connect(String token) {
    _token = token;
    _stopped = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connectNow();
  }

  void _connectNow() {
    if (_channel != null || _connecting) return;
    _setState(WsConnectionState.connecting);
    final token = _token;
    if (token == null) return;

    _connecting = true;
    final uri = Uri.parse(
      '$_wsBaseUrl/ws/telemetry',
    ).replace(queryParameters: {'token': token});
    final channel = _channelFactory(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onDone: _onDone,
      // A stream error (rare — most WS failures surface as onDone with a
      // close code) must not crash the app; treat it the same as a drop.
      onError: (Object _) => _onDone(),
      cancelOnError: true,
    );

    unawaited(
      channel.ready
          .then((_) {
            _connecting = false;
            _setState(WsConnectionState.open);
            // Deliberately NOT resetting `_reconnectAttempts` here — design
            // §6.1 names exactly two reset triggers, `resume()` (lifecycle
            // resume / connectivity regain) and a fresh `connect()`, both
            // external signals. A connection that flaps (succeeds, then
            // drops again immediately) must keep counting toward the same
            // 8-attempt budget, not get an unlimited retry loop for free.
            if (_hasConnectedOnce) {
              onReconnected?.call();
            }
            _hasConnectedOnce = true;
          })
          .catchError((Object _) {
            // `ready` failing means `_onDone` will also fire once the
            // channel notices; just stop tracking this attempt as pending.
            _connecting = false;
          }),
    );
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
    final event = parseWsEvent(message);
    if (event != null) _controller.add(event);
  }

  void _onDone() {
    final closeCode = _channel?.closeCode;
    _channel = null;
    _connecting = false;
    if (_stopped) return;

    if (closeCode == _sessionInvalidCloseCode) {
      _setState(WsConnectionState.closed);
      onSessionInvalid?.call();
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setState(WsConnectionState.closed);
      return;
    }
    final delay = _backoffDelay(_reconnectAttempts);
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _connectNow);
    _setState(WsConnectionState.reconnecting);
  }

  /// Full jitter: a uniformly random delay between 0 and
  /// `min(cap, base * 2^attempt)` (design §6.1 WS-4).
  Duration _backoffDelay(int attempt) {
    final exponentialMs =
        _baseBackoff.inMilliseconds * math.pow(2, attempt).toInt();
    final boundMs = math.min(exponentialMs, _capBackoff.inMilliseconds);
    final jitterMs = _random.nextInt(boundMs + 1);
    return Duration(milliseconds: jitterMs);
  }

  /// WS-5: closes with code 1000 and does NOT schedule a reconnect —
  /// `AppLifecycleState.paused`/`detached` are allowed to drop the socket.
  void suspend() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _teardownChannel();
    _setState(WsConnectionState.closed);
  }

  /// WS-5: resets the reconnect budget and connects immediately, called on
  /// `AppLifecycleState.resumed` (after the caller's own JWT `exp` check)
  /// and on connectivity regain.
  void resume(String token) {
    _token = token;
    _stopped = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connectNow();
  }

  /// WS-3: closes synchronously as part of logout teardown, before
  /// navigation completes. Terminal — this instance is not reused; a fresh
  /// `TelemetrySocket` is constructed for the next session.
  void close() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _teardownChannel();
    _setState(WsConnectionState.closed);
    unawaited(_controller.close());
  }

  void _teardownChannel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_channel?.sink.close(_normalCloseCode));
    _channel = null;
    _connecting = false;
  }
}
