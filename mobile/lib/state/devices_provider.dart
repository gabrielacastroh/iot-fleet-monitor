import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/device.dart';
import 'cached.dart';
import 'repository_providers.dart';

/// Peek-then-refetch over `GET /devices` (design §6). Resolves the async
/// [deviceRepositoryProvider] first, then delegates the cache/refresh
/// mechanics to [CacheBackedNotifier].
class DevicesNotifier extends AsyncNotifier<Cached<List<Device>>>
    with CacheBackedNotifier<List<Device>> {
  CachedSource<List<Device>>? _repository;

  @override
  CachedSource<List<Device>> get source => _repository!;

  @override
  Future<Cached<List<Device>>> build() async {
    _repository = await ref.watch(deviceRepositoryProvider.future);
    return super.build();
  }
}

final devicesProvider =
    AsyncNotifierProvider<DevicesNotifier, Cached<List<Device>>>(
      DevicesNotifier.new,
    );
