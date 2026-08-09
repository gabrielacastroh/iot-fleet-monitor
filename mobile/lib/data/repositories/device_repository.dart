import '../../domain/models/device.dart';
import '../../state/cached.dart';
import '../api/devices_api.dart';
import '../local/cache_entry.dart';
import '../local/fleet_cache.dart';

/// `GET /devices`, `GET /devices/{id}` — cached under [FleetCache.devicesKey]
/// (design §5.3). No pagination exists; the whole fleet is fetched.
class DeviceRepository implements CachedSource<List<Device>> {
  DeviceRepository(this._api, this._cache);

  final DevicesApi _api;
  final FleetCache _cache;

  static const _maxAge = Duration(hours: 24);

  @override
  Cached<List<Device>>? peekCache() {
    final entry = _cache.read(FleetCache.devicesKey);
    if (entry == null) return null;
    if (DateTime.now().toUtc().difference(entry.cachedAt) > _maxAge) {
      return null;
    }
    final devices = (entry.payload as List<dynamic>)
        .map((json) => Device.fromJson(json as Map<String, dynamic>))
        .toList();
    return Cached(devices, cachedAt: entry.cachedAt);
  }

  @override
  Future<List<Device>> fetchAndCache() async {
    final devices = await _api.getAll();
    await _cache.write(
      FleetCache.devicesKey,
      CacheEntry(
        cachedAt: DateTime.now().toUtc(),
        payload: devices.map((d) => d.toJson()).toList(),
      ),
    );
    return devices;
  }

  /// Serves the cached list first, then hits `/devices/{id}` for a fresh
  /// copy (design §5.3); falls back to the cached entry if the network
  /// call fails.
  Future<Device> getById(String id) async {
    final cached = peekCache()?.value;
    final cachedDevice = _findById(cached, id);
    try {
      return await _api.getById(id);
    } catch (e) {
      if (cachedDevice != null) return cachedDevice;
      rethrow;
    }
  }

  Device? _findById(List<Device>? devices, String id) {
    if (devices == null) return null;
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }
}
