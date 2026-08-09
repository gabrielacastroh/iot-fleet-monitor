"""Fleet assembly: seeding, composition and the identifiers the backend indexes."""

from simulator.config import SimulatorConfig
from simulator.fleet import build_fleet, vehicle_rng
from simulator.scenarios import VehicleProfile
from simulator.vehicle import tick


def _config(**overrides) -> SimulatorConfig:
    return SimulatorConfig(email="a@a.com", password="x", **overrides)


def _drive(config: SimulatorConfig, ticks: int = 25):
    """Runs a whole fleet forward, the way `_run_vehicle` does, and returns the
    readings each vehicle produced."""
    vehicles = build_fleet(config)
    return [
        [
            tick(vehicle, config, config.interval_seconds / 3600, vehicle_rng(config.seed, index))
            for _ in range(ticks)
        ]
        for index, vehicle in enumerate(vehicles)
    ]


def test_the_same_seed_reproduces_the_same_fleet():
    config = _config(seed=42, scenario="demo")

    first = build_fleet(config)
    second = build_fleet(config)

    assert [(v.device_code, v.latitude, v.longitude, v.fuel_level) for v in first] == [
        (v.device_code, v.latitude, v.longitude, v.fuel_level) for v in second
    ]


def test_the_same_seed_reproduces_the_same_readings():
    config = _config(seed=42, scenario="demo")

    assert _drive(config) == _drive(config)


def test_a_different_seed_produces_a_different_fleet():
    fuel_a = [v.fuel_level for v in build_fleet(_config(seed=1, scenario="demo"))]
    fuel_b = [v.fuel_level for v in build_fleet(_config(seed=2, scenario="demo"))]

    assert fuel_a != fuel_b


def test_no_seed_leaves_the_run_random():
    fuel_a = [v.fuel_level for v in build_fleet(_config(device_count=5))]
    fuel_b = [v.fuel_level for v in build_fleet(_config(device_count=5))]

    assert fuel_a != fuel_b


def test_each_vehicle_draws_from_its_own_stream():
    """A single shared generator would hand out draws in event-loop order, so
    a seeded run would still differ between executions."""
    a = vehicle_rng(42, 0)
    b = vehicle_rng(42, 1)

    assert [a.random() for _ in range(5)] != [b.random() for _ in range(5)]


def test_a_vehicles_setup_and_driving_draws_do_not_replay_each_other():
    init = vehicle_rng(42, 0, "init")
    drive = vehicle_rng(42, 0, "tick")

    assert [init.random() for _ in range(5)] != [drive.random() for _ in range(5)]


def test_default_scenario_builds_the_requested_number_of_vehicles():
    assert len(build_fleet(_config(device_count=7))) == 7


def test_demo_scenario_differentiates_the_vehicles():
    fleet = build_fleet(_config(seed=42, scenario="demo"))

    # Distinct starting tanks, positions and headings — not one template
    # repeated six times.
    assert len({v.fuel_level for v in fleet}) == len(fleet)
    assert len({(v.latitude, v.longitude) for v in fleet}) == len(fleet)

    critical = next(v for v in fleet if v.profile.label == "critical")
    normals = [v for v in fleet if v.profile.label == "normal"]
    assert all(critical.consumption_per_hour > v.consumption_per_hour for v in normals)


def test_device_code_and_plate_share_the_configured_prefix():
    """They used to diverge: the code followed --device-prefix while the plate
    was always SIM..., so any non-default prefix collided with the plates an
    earlier run had already registered and the backend answered 409 on a device
    code that did not exist yet."""
    fleet = build_fleet(_config(device_prefix="TRUCK", device_count=2))

    assert [v.device_code for v in fleet] == ["TRUCK-001", "TRUCK-002"]
    assert [v.plate for v in fleet] == ["TRUCK001", "TRUCK002"]


def test_plates_stay_unique_and_within_the_backend_column():
    fleet = build_fleet(_config(device_prefix="LONGPREFIXFORAFLEET", device_count=12))

    plates = [v.plate for v in fleet]
    assert len(set(plates)) == len(plates)
    assert all(len(plate) <= 20 for plate in plates)


def test_two_prefixes_never_collide_on_a_plate():
    a = {v.plate for v in build_fleet(_config(device_prefix="SIM", device_count=5))}
    b = {v.plate for v in build_fleet(_config(device_prefix="TRUCK", device_count=5))}

    assert a.isdisjoint(b)


def test_profiles_from_a_config_file_drive_the_fleet():
    config = _config(
        seed=7,
        profiles=(
            VehicleProfile(label="thirsty", count=2, fuel_min=20.0, fuel_max=25.0, consumption_per_hour=45.0),
        ),
    )

    fleet = build_fleet(config)

    assert len(fleet) == 2
    assert all(20.0 <= v.fuel_level <= 25.0 for v in fleet)
    assert all(v.consumption_per_hour == 45.0 for v in fleet)
