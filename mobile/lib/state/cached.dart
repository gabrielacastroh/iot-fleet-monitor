import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps a value with the timestamp it was cached at. `cachedAt == null`
/// means the value came straight from the network this call. See design
/// §5.2.
class Cached<T> {
  const Cached(this.value, {this.cachedAt});

  final T value;
  final DateTime? cachedAt;

  bool get isStale => cachedAt != null;
}

/// The read-through contract every repository implements (design §5.2).
abstract interface class CachedSource<T> {
  /// Synchronous, no await, no spinner — the last value written to disk,
  /// or `null` if there is none (or it is past the 24h hard bound).
  Cached<T>? peekCache();

  /// Network fetch; throws a `Failure` on any error. Writes the cache on
  /// success.
  Future<T> fetchAndCache();
}

/// The peek-then-refetch pattern shared by every data notifier (design
/// §5.2): `build()` paints instantly from [CachedSource.peekCache] when a
/// cache entry exists, then a background [refresh] replaces it. A screen
/// never shows a spinner over stale data — [AsyncStateView] renders a
/// [StalenessBar] instead, driven by `state.hasError` + the previous value
/// `copyWithPrevious` preserves.
mixin CacheBackedNotifier<T> on AsyncNotifier<Cached<T>> {
  CachedSource<T> get source;

  @override
  Future<Cached<T>> build() async {
    final cached = source.peekCache();
    if (cached == null) {
      return Cached(await source.fetchAndCache());
    }
    // Scheduled as a real event-loop turn (not a microtask) so it runs
    // strictly after the framework has installed this build's initial
    // state — refresh() reads `state`, which isn't safe to touch while
    // build() itself is still resolving.
    unawaited(Future(refresh));
    return cached;
  }

  /// Re-fetches in the background and replaces the cached value on
  /// success. On failure, the resulting `AsyncError` still carries the
  /// previous value via `copyWithPrevious` so `AsyncStateView` can paint
  /// stale data with a `StalenessBar` instead of the error state.
  Future<void> refresh() async {
    final previousState = state;
    state = AsyncValue<Cached<T>>.loading().copyWithPrevious(previousState);
    final result = await AsyncValue.guard(
      () async => Cached(await source.fetchAndCache()),
    );
    state = result.hasError ? result.copyWithPrevious(previousState) : result;
  }
}
