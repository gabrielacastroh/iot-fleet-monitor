"""One simulated vehicle: pure state transition, no I/O. `tick()` is what a
test drives directly and what the orchestrator drives on a timer — the same
function either way, which is what makes the physics testable without a
running backend or a real clock.
"""

from __future__ import annotations

import random
from dataclasses import dataclass

from simulator.config import SimulatorConfig
from simulator.motion import bearing_to, distance_km, step
from simulator.scenarios import NORMAL_PROFILE, VehicleProfile

FUEL_FULL = 100.0
FUEL_EMPTY = 0.0

# Below this, a vehicle counts as stopped rather than crawling — it burns the
# idle rate, not the driving rate.
MOVING_SPEED_THRESHOLD_KMH = 5.0

# How much the fuel burned in one tick swings around the nominal rate. Traffic,
# gradient and a sensor that is not a calculator. A profile can narrow it —
# CRITICAL_PROFILE does, because a vehicle whose job is to cross the backend's
# alert threshold has to cross it decisively.
CONSUMPTION_JITTER = 0.15

# Fuel is reported at this precision. It used to be one decimal, which quantised
# the drop across the backend's fuel window so coarsely that the consumption it
# measured could only land on a couple of discrete values — and those straddled
# the one-hour autonomy threshold, so a single low tank produced dozens of
# alerts instead of one. Four decimals is still a plausible sensor and leaves
# the rate smooth.
FUEL_DECIMALS = 4


@dataclass(frozen=True, slots=True)
class TelemetrySample:
    latitude: float
    longitude: float
    speed: float
    fuel_level: float
    temperature: float


@dataclass(slots=True)
class VehicleState:
    device_code: str
    vehicle_name: str
    plate: str
    latitude: float
    longitude: float
    heading: float
    speed: float
    fuel_level: float
    temperature: float
    #: Percent of tank per hour while driving. Held per vehicle rather than
    #: read from the config, so one profile can burn fuel far faster than the
    #: rest of the fleet without a second config knob.
    consumption_per_hour: float
    #: Chance of stopping on any given tick, per vehicle for the same reason.
    idle_probability: float
    #: The profile this vehicle was built from — the orchestrator reads its
    #: reporting rules off it.
    profile: VehicleProfile = NORMAL_PROFILE
    #: >0 while "at the pump": speed pinned to 0 and fuel held until it hits 0.
    refuel_ticks_left: int = 0


# The maximum length the backend's `plate` column accepts.
PLATE_MAX_LENGTH = 20


def plate_for(device_prefix: str, index: int) -> str:
    """Plate derived from the same prefix and number as the device code.

    They used to diverge — the code followed `--device-prefix` while the plate
    was always `SIM...` — so any non-default prefix collided with the plates a
    previous run had already registered, and the backend answered 409 on a
    device code that did not exist yet.

    A long prefix is trimmed rather than the whole plate: the number is what
    makes one plate different from the next, and truncating the tail would hand
    the backend the same value for every vehicle.
    """
    number = f"{index + 1:03d}"
    return f"{device_prefix[: PLATE_MAX_LENGTH - len(number)]}{number}"


def device_code_for(device_prefix: str, index: int) -> str:
    return f"{device_prefix}-{index + 1:03d}"


def new_vehicle(
    index: int,
    config: SimulatorConfig,
    rng: random.Random,
    profile: VehicleProfile = NORMAL_PROFILE,
) -> VehicleState:
    start_angle = rng.uniform(0, 360)
    start_distance = rng.uniform(0, config.radius_km * 0.6)
    latitude, longitude = step(config.center_latitude, config.center_longitude, start_angle, start_distance)

    return VehicleState(
        device_code=device_code_for(config.device_prefix, index),
        vehicle_name=f"Vehicle {index + 1}",
        plate=plate_for(config.device_prefix, index),
        latitude=latitude,
        longitude=longitude,
        heading=rng.uniform(0, 360),
        speed=config.speed_cruise_kmh,
        fuel_level=rng.uniform(profile.fuel_min, profile.fuel_max),
        temperature=config.temperature_base,
        consumption_per_hour=(
            profile.consumption_per_hour
            if profile.consumption_per_hour is not None
            else config.fuel_consumption_per_hour
        ),
        idle_probability=(
            profile.idle_probability
            if profile.idle_probability is not None
            else config.idle_probability
        ),
        profile=profile,
    )


def tick(
    state: VehicleState, config: SimulatorConfig, dt_hours: float, rng: random.Random
) -> TelemetrySample:
    """Advances `state` by one interval in place and returns the reading it
    produces. In place because a vehicle's whole point is continuity — its
    next position, speed and fuel all depend on where it already was."""
    if state.refuel_ticks_left > 0:
        state.refuel_ticks_left -= 1
        state.speed = 0.0
        if state.refuel_ticks_left == 0:
            state.fuel_level = _refuel_to(state)
        return _sample(state)

    state.speed = _next_speed(state, config, rng)
    state.heading = _next_heading(state, config, rng)
    distance = state.speed * dt_hours
    state.latitude, state.longitude = step(state.latitude, state.longitude, state.heading, distance)

    state.fuel_level = _next_fuel(state, config, dt_hours, rng)
    if config.fuel_refuel_enabled and state.fuel_level <= _refuel_at(state, config):
        # Pause running, not an instant refill: this gives the backend's own
        # LOW_FUEL alert (see AlertService.sync_fuel_alert) time to actually
        # fire and stay visible before the tank is full again.
        state.refuel_ticks_left = config.fuel_refuel_pause_ticks

    state.temperature = _next_temperature(state, config, rng)

    return _sample(state)


# Where a vehicle refuels and how much it takes on. A profile that says nothing
# behaves the way the whole fleet always did: run down to the fleet-wide
# critical level, then fill the tank.
def _refuel_at(state: VehicleState, config: SimulatorConfig) -> float:
    if state.profile.refuel_at is not None:
        return state.profile.refuel_at
    return config.fuel_critical_threshold


def _refuel_to(state: VehicleState) -> float:
    if state.profile.refuel_to is not None:
        return state.profile.refuel_to
    return FUEL_FULL


def _sample(state: VehicleState) -> TelemetrySample:
    return TelemetrySample(
        latitude=round(state.latitude, 6),
        longitude=round(state.longitude, 6),
        speed=round(max(state.speed, 0.0), 1),
        fuel_level=round(min(max(state.fuel_level, FUEL_EMPTY), FUEL_FULL), FUEL_DECIMALS),
        temperature=round(state.temperature, 1),
    )


def _next_speed(state: VehicleState, config: SimulatorConfig, rng: random.Random) -> float:
    if rng.random() < state.idle_probability:
        return 0.0  # a traffic light, a stop — visible as a dip on the live speed chart
    drift = rng.uniform(-config.speed_variance_kmh, config.speed_variance_kmh)
    pull_to_cruise = (config.speed_cruise_kmh - state.speed) * 0.1
    return min(max(state.speed + drift + pull_to_cruise, 0.0), config.speed_max_kmh)


def _next_heading(state: VehicleState, config: SimulatorConfig, rng: random.Random) -> float:
    heading = (state.heading + rng.uniform(-15, 15)) % 360
    if distance_km(state.latitude, state.longitude, config.center_latitude, config.center_longitude) > config.radius_km:
        # Wandered past the operating radius: steer back toward the centre
        # instead of drifting off the map forever.
        to_center = bearing_to(state.latitude, state.longitude, config.center_latitude, config.center_longitude)
        heading = (to_center + rng.uniform(-20, 20)) % 360
    return heading


def _next_fuel(state: VehicleState, config: SimulatorConfig, dt_hours: float, rng: random.Random) -> float:
    rate = (
        state.consumption_per_hour
        if state.speed > MOVING_SPEED_THRESHOLD_KMH
        else config.fuel_idle_consumption_per_hour
    )
    jitter = (
        state.profile.consumption_jitter
        if state.profile.consumption_jitter is not None
        else CONSUMPTION_JITTER
    )
    consumed = rate * dt_hours * rng.uniform(1.0 - jitter, 1.0 + jitter)
    return max(state.fuel_level - consumed, FUEL_EMPTY)


def _next_temperature(state: VehicleState, config: SimulatorConfig, rng: random.Random) -> float:
    engine_load = (state.speed / config.speed_max_kmh) * 12.0
    noise = rng.uniform(-config.temperature_variance, config.temperature_variance)
    return config.temperature_base + engine_load + noise
