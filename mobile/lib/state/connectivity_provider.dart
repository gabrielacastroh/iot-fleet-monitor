import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The raw `connectivity_plus` client, split out purely so tests can
/// override it with a `mocktail` double (design §8 — OFF-1).
final connectivityClientProvider = Provider<Connectivity>(
  (ref) => Connectivity(),
);

/// OFF-1: `online = interfaceUp && lastRequestReachable` (design §8).
/// Neither signal alone is sufficient — a captive-portal wifi still
/// reports "connected" at the interface level, and a single failed
/// request could just be that one endpoint being briefly down.
/// [reportReachability] is fed by [ErrorInterceptor.onReachabilityChanged]
/// (wired in `api_providers.dart`); no `/health` polling.
class ConnectivityNotifier extends Notifier<bool> {
  bool _interfaceUp = true;
  bool _lastRequestReachable = true;

  @override
  bool build() {
    final connectivity = ref.watch(connectivityClientProvider);
    final subscription = connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    ref.onDispose(subscription.cancel);
    // Seed the real interface state; `build()` returns optimistically
    // (`true`) until this resolves, matching every other provider's
    // cache-then-refresh discipline of never blocking first paint.
    connectivity.checkConnectivity().then(_onConnectivityChanged);
    return true;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _interfaceUp = results.any((r) => r != ConnectivityResult.none);
    _recompute();
  }

  void reportReachability(bool reachable) {
    _lastRequestReachable = reachable;
    _recompute();
  }

  void _recompute() {
    state = _interfaceUp && _lastRequestReachable;
  }
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);
