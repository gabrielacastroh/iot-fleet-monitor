import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/state/cached.dart';

class _FakeSource implements CachedSource<int> {
  _FakeSource({this.cached, required this.fetchResults});

  Cached<int>? cached;
  final List<Future<int> Function()> fetchResults;
  int callCount = 0;

  @override
  Cached<int>? peekCache() => cached;

  @override
  Future<int> fetchAndCache() {
    final fn = fetchResults[callCount];
    callCount++;
    return fn();
  }
}

class _TestNotifier extends AsyncNotifier<Cached<int>>
    with CacheBackedNotifier<int> {
  _TestNotifier(this._source);

  final CachedSource<int> _source;

  @override
  CachedSource<int> get source => _source;
}

void main() {
  test('Cached.isStale is true only when cachedAt is set', () {
    expect(const Cached(1).isStale, isFalse);
    expect(Cached(1, cachedAt: DateTime.utc(2026)).isStale, isTrue);
  });

  test(
    'build() paints from cache instantly, then a background refresh replaces it',
    () async {
      final source = _FakeSource(
        cached: Cached(1, cachedAt: DateTime.utc(2026)),
        fetchResults: [() async => 2],
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = AsyncNotifierProvider<_TestNotifier, Cached<int>>(
        () => _TestNotifier(source),
      );

      final initial = await container.read(provider.future);
      expect(initial.value, 1);
      expect(initial.isStale, isTrue);

      // Let the background refresh (scheduled as a real event-loop turn
      // after build() settles) run.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final refreshed = container.read(provider);
      expect(refreshed.value?.value, 2);
      expect(refreshed.value?.isStale, isFalse);
    },
  );

  test(
    'a failed refresh surfaces AsyncError but keeps the previous cached value reachable',
    () async {
      final source = _FakeSource(
        cached: Cached(1, cachedAt: DateTime.utc(2026)),
        fetchResults: [() async => throw Exception('network down')],
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = AsyncNotifierProvider<_TestNotifier, Cached<int>>(
        () => _TestNotifier(source),
      );

      await container.read(provider.future);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(provider);
      expect(state.hasError, isTrue);
      expect(state.valueOrNull?.value, 1);
    },
  );

  test('no cache: build() awaits the network fetch directly', () async {
    final source = _FakeSource(cached: null, fetchResults: [() async => 42]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = AsyncNotifierProvider<_TestNotifier, Cached<int>>(
      () => _TestNotifier(source),
    );

    final value = await container.read(provider.future);
    expect(value.value, 42);
    expect(value.isStale, isFalse);
  });
}
