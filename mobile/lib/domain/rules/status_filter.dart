import 'fleet_status.dart';

/// The status filter vocabulary shared by every screen that narrows a
/// fleet by state: `all` plus one entry per [FleetStatus] value, including
/// `critical` per the vehicles spec's risk resolution #1.
///
/// Lives in `domain/rules` rather than beside one screen's provider because
/// the vehicles list (VEH-3) and the map (MAP-4) filter the same five
/// states — a second parallel enum would let them drift apart.
enum VehicleStatusTab { all, active, inactive, noSignal, alert, critical }

extension VehicleStatusTabX on VehicleStatusTab {
  /// The [FleetStatus] this tab filters by. Not defined for `all`, which
  /// matches every status instead of one.
  FleetStatus get status => switch (this) {
    VehicleStatusTab.all => throw StateError('"all" matches every status.'),
    VehicleStatusTab.active => FleetStatus.active,
    VehicleStatusTab.inactive => FleetStatus.inactive,
    VehicleStatusTab.noSignal => FleetStatus.noSignal,
    VehicleStatusTab.alert => FleetStatus.alert,
    VehicleStatusTab.critical => FleetStatus.critical,
  };
}
