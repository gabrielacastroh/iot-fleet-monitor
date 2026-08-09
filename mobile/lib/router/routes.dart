/// Path constants — no string literals at call sites (design §7). Grows as
/// later slices add branches (alerts, profile).
class Routes {
  const Routes._();

  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const vehicles = '/vehicles';
  static const map = '/map';
  static const alerts = '/alerts';
  static const profile = '/profile';

  /// `/vehicles/:deviceId` (VDET's detail route).
  static String vehicleDetail(String deviceId) => '$vehicles/$deviceId';

  /// `/alerts/:alertId[?deviceId=]` — ALT-2's cold-deep-link fallback
  /// chain uses [deviceId] (when present) as its second resolution step.
  static String alertDetail(String alertId, {String? deviceId}) {
    final path = '$alerts/$alertId';
    return deviceId == null ? path : '$path?deviceId=$deviceId';
  }
}
