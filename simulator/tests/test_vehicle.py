import random

import pytest

from simulator.config import SimulatorConfig
from simulator.motion import distance_km
from simulator.scenarios import VehicleProfile
from simulator.vehicle import new_vehicle, tick


def _config(**overrides) -> SimulatorConfig:
    return SimulatorConfig(email="a@a.com", password="x", **overrides)


def test_new_vehicle_starts_within_the_operating_radius():
    config = _config(radius_km=10.0)
    vehicle = new_vehicle(0, config, random.Random(1))

    assert distance_km(
        vehicle.latitude, vehicle.longitude, config.center_latitude, config.center_longitude
    ) <= 10.0


def test_device_codes_are_stable_and_zero_padded():
    config = _config(device_prefix="FLEET")
    rng = random.Random(1)

    assert new_vehicle(0, config, rng).device_code == "FLEET-001"
    assert new_vehicle(9, config, rng).device_code == "FLEET-010"


def test_fuel_decreases_while_moving():
    config = _config(fuel_consumption_per_hour=10.0, idle_probability=0.0)
    rng = random.Random(1)
    vehicle = new_vehicle(0, config, rng)
    vehicle.fuel_level = 50.0
    vehicle.speed = config.speed_cruise_kmh

    sample = tick(vehicle, config, dt_hours=1.0, rng=rng)

    assert sample.fuel_level < 50.0


def test_fuel_never_goes_negative():
    config = _config(fuel_consumption_per_hour=1000.0, fuel_refuel_enabled=False)
    rng = random.Random(1)
    vehicle = new_vehicle(0, config, rng)
    vehicle.fuel_level = 1.0

    sample = tick(vehicle, config, dt_hours=1.0, rng=rng)

    assert sample.fuel_level >= 0.0


def test_speed_never_exceeds_the_configured_max():
    config = _config(speed_max_kmh=80.0, speed_variance_kmh=1000.0, idle_probability=0.0)
    rng = random.Random(1)
    vehicle = new_vehicle(0, config, rng)

    for _ in range(20):
        sample = tick(vehicle, config, dt_hours=0.01, rng=rng)
        assert 0.0 <= sample.speed <= 80.0


def test_an_empty_tank_triggers_a_refuel_pause_before_refilling():
    """A hard drop to 0 must not resolve instantly: the backend's LOW_FUEL
    alert needs at least one tick where the vehicle is visibly out, or the
    demo never shows the alert firing."""
    config = _config(
        fuel_consumption_per_hour=1000.0,
        fuel_refuel_enabled=True,
        fuel_critical_threshold=5.0,
        fuel_refuel_pause_ticks=2,
    )
    rng = random.Random(1)
    vehicle = new_vehicle(0, config, rng)
    vehicle.fuel_level = 4.0

    empty = tick(vehicle, config, dt_hours=1.0, rng=rng)
    assert empty.fuel_level == 0.0
    assert vehicle.refuel_ticks_left == 2

    stopped = tick(vehicle, config, dt_hours=1.0, rng=rng)
    assert stopped.speed == 0.0
    assert stopped.fuel_level == 0.0  # still refuelling, not topped up yet

    refuelled = tick(vehicle, config, dt_hours=1.0, rng=rng)
    assert refuelled.fuel_level == 100.0
    assert vehicle.refuel_ticks_left == 0


def test_refuel_disabled_leaves_the_tank_at_zero():
    config = _config(fuel_consumption_per_hour=1000.0, fuel_refuel_enabled=False)
    rng = random.Random(1)
    vehicle = new_vehicle(0, config, rng)
    vehicle.fuel_level = 4.0

    for _ in range(5):
        sample = tick(vehicle, config, dt_hours=1.0, rng=rng)

    assert sample.fuel_level == 0.0
    assert vehicle.refuel_ticks_left == 0


def test_a_vehicle_that_overshoots_its_radius_steers_back():
    config = _config(
        radius_km=5.0,
        speed_cruise_kmh=200.0,
        speed_max_kmh=200.0,
        speed_variance_kmh=0.0,
        idle_probability=0.0,
        fuel_refuel_enabled=False,
    )
    rng = random.Random(1)
    vehicle = new_vehicle(0, config, rng)
    vehicle.speed = 200.0

    for _ in range(30):
        tick(vehicle, config, dt_hours=0.05, rng=rng)

    # Not a hard per-tick guarantee given the randomness, but the heading
    # correction must keep it from escaping indefinitely.
    assert (
        distance_km(vehicle.latitude, vehicle.longitude, config.center_latitude, config.center_longitude)
        < config.radius_km * 3
    )


def test_a_profile_sets_the_starting_tank():
    profile = VehicleProfile(label="low", fuel_min=10.0, fuel_max=12.0)

    for seed in range(20):
        vehicle = new_vehicle(0, _config(), random.Random(seed), profile)
        assert 10.0 <= vehicle.fuel_level <= 12.0


def test_a_profile_can_burn_faster_than_the_rest_of_the_fleet():
    config = _config(fuel_consumption_per_hour=9.0, idle_probability=0.0)
    thirsty = VehicleProfile(label="thirsty", consumption_per_hour=60.0)

    normal = new_vehicle(0, config, random.Random(1))
    fast = new_vehicle(1, config, random.Random(1), thirsty)
    normal.fuel_level = fast.fuel_level = 80.0

    normal_sample = tick(normal, config, dt_hours=0.5, rng=random.Random(3))
    fast_sample = tick(fast, config, dt_hours=0.5, rng=random.Random(3))

    assert fast_sample.fuel_level < normal_sample.fuel_level


def test_a_profile_without_overrides_follows_the_fleet_wide_settings():
    config = _config(fuel_consumption_per_hour=9.0, idle_probability=0.25)

    vehicle = new_vehicle(0, config, random.Random(1))

    assert vehicle.consumption_per_hour == 9.0
    assert vehicle.idle_probability == 0.25


def test_a_profile_can_pin_a_vehicle_to_never_idling():
    """The critical vehicle relies on this: an idle stop inside the backend's
    still-short startup window collapses the consumption it measures."""
    config = _config(idle_probability=1.0)
    never_idle = VehicleProfile(label="highway", idle_probability=0.0)

    vehicle = new_vehicle(0, config, random.Random(1), never_idle)
    speeds = [tick(vehicle, config, 1 / 120, random.Random(seed)).speed for seed in range(30)]

    assert all(speed > 0.0 for speed in speeds)


def test_reported_fuel_keeps_enough_precision_for_the_backends_window():
    """One decimal quantised the drop across the backend's fuel window so
    coarsely that the measured consumption oscillated across the alert
    threshold. See tests/test_fuel_alert.py for the rule-level assertion."""
    config = _config(fuel_consumption_per_hour=9.0, idle_probability=0.0, interval_seconds=30.0)
    vehicle = new_vehicle(0, config, random.Random(1))
    vehicle.fuel_level = 50.0

    first = tick(vehicle, config, config.interval_seconds / 3600, random.Random(2))
    second = tick(vehicle, config, config.interval_seconds / 3600, random.Random(3))

    # A 30s tick at 9%/h burns ~0.075% — invisible at one decimal.
    assert first.fuel_level != second.fuel_level


def test_reported_fuel_stays_inside_the_backend_schema_range():
    config = _config(fuel_consumption_per_hour=400.0)
    vehicle = new_vehicle(0, config, random.Random(1))

    for _ in range(50):
        sample = tick(vehicle, config, dt_hours=0.2, rng=random.Random(1))
        assert 0.0 <= sample.fuel_level <= 100.0


def test_tick_is_deterministic_for_a_given_seed():
    config = _config()
    vehicle_a = new_vehicle(0, config, random.Random(42))
    vehicle_b = new_vehicle(0, config, random.Random(42))

    sample_a = tick(vehicle_a, config, dt_hours=1 / 720, rng=random.Random(7))
    sample_b = tick(vehicle_b, config, dt_hours=1 / 720, rng=random.Random(7))

    assert sample_a == sample_b
