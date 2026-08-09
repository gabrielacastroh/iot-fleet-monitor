"""Named fleet compositions.

A scenario is just a list of vehicle profiles, and a profile is the handful of
knobs that make one vehicle behave differently from its neighbours: where its
tank starts, how fast it burns, and whether it reports at all. Keeping this as
data rather than branching on a vehicle index is what lets `--scenario` stay a
single flag while the fleet it builds is still described in one readable place.

Nothing here talks to the backend or rolls a die — `fleet.py` expands a
scenario into vehicles and hands each one its own seeded RNG.
"""

from __future__ import annotations

from dataclasses import dataclass, fields, replace
from math import ceil
from typing import Any

# Burn rate for the vehicle whose whole job is to trip the backend's predictive
# rule. The point of the demo is that autonomy is not a fuel threshold: this
# vehicle reports a perfectly ordinary-looking gauge and still falls under an
# hour of range, because it is drinking the tank at 60% per hour.
CRITICAL_CONSUMPTION_PER_HOUR = 60.0


@dataclass(frozen=True, slots=True)
class VehicleProfile:
    """How one kind of vehicle in the fleet behaves.

    `count` vehicles are built from each profile. Every field except `label`
    has a default, so a scenario only spells out what makes it different.
    """

    label: str
    count: int = 1

    #: Inclusive range the starting tank is drawn from, in percent.
    fuel_min: float = 60.0
    fuel_max: float = 100.0

    #: Overrides `SimulatorConfig.fuel_consumption_per_hour` for this profile.
    #: None means "use the fleet-wide rate".
    consumption_per_hour: float | None = None

    #: Overrides `SimulatorConfig.idle_probability`. None means "use the
    #: fleet-wide chance". A vehicle that stops burns the idle rate, which
    #: drags the consumption the backend measures across its window — see
    #: CRITICAL_PROFILE for why that matters to one profile in particular.
    idle_probability: float | None = None

    #: How much the fuel burned in one tick swings around the nominal rate,
    #: as a fraction. None means the fleet-wide default in `vehicle.py`. It is
    #: a profile knob because it decides whether a vehicle can cross the
    #: backend's alert threshold cleanly — see CRITICAL_PROFILE.
    consumption_jitter: float | None = None

    #: Fuel level that sends this vehicle to the pump, and the level it leaves
    #: with. None means the fleet-wide `fuel_critical_threshold` and a full
    #: tank. A profile that refuels well before empty cycles through the
    #: backend's alert band far faster than one that drains to zero — see
    #: CRITICAL_PROFILE.
    refuel_at: float | None = None
    refuel_to: float | None = None

    #: Stop sending telemetry after this many readings. None means "never
    #: stop"; 0 means the device registers and never reports at all.
    silent_after_ticks: int | None = None

    #: Registered on the device itself. An inactive device is a registry
    #: state, not a reporting one — see the module note in SETUP.md.
    is_active: bool = True

    def validate(self) -> None:
        if self.count < 1:
            raise ValueError(f"profile '{self.label}': count must be at least 1")
        if not 0.0 <= self.fuel_min <= self.fuel_max <= 100.0:
            raise ValueError(
                f"profile '{self.label}': fuel range must satisfy 0 <= min <= max <= 100"
            )
        if self.consumption_per_hour is not None and self.consumption_per_hour < 0:
            raise ValueError(f"profile '{self.label}': consumption_per_hour cannot be negative")
        if self.idle_probability is not None and not 0.0 <= self.idle_probability <= 1.0:
            raise ValueError(f"profile '{self.label}': idle_probability must be between 0 and 1")
        if self.consumption_jitter is not None and not 0.0 <= self.consumption_jitter < 1.0:
            raise ValueError(
                f"profile '{self.label}': consumption_jitter must be between 0 and 1"
            )
        for name, level in (("refuel_at", self.refuel_at), ("refuel_to", self.refuel_to)):
            if level is not None and not 0.0 <= level <= 100.0:
                raise ValueError(f"profile '{self.label}': {name} must be between 0 and 100")
        if (
            self.refuel_at is not None
            and self.refuel_to is not None
            and self.refuel_to <= self.refuel_at
        ):
            raise ValueError(f"profile '{self.label}': refuel_to must be above refuel_at")
        if self.silent_after_ticks is not None and self.silent_after_ticks < 0:
            raise ValueError(f"profile '{self.label}': silent_after_ticks cannot be negative")


NORMAL_PROFILE = VehicleProfile(label="normal")

# A vehicle that is registered but has never reported. The dashboard reads
# "sin señal" off a null `last_seen_at`, so staying silent from the first tick
# is what actually produces that state — see SETUP.md for why a vehicle that
# goes quiet *later* keeps reading as "activo".
NO_SIGNAL_PROFILE = VehicleProfile(label="no-signal", silent_after_ticks=0)

# Registered with is_active=false and never reporting, which is the only
# representation of "inactivo" the current device contract supports.
INACTIVE_PROFILE = VehicleProfile(label="inactive", is_active=False, silent_after_ticks=0)

# Autonomy is fuel divided by measured consumption, so the one-hour line sits
# at whatever percent of tank the burn rate is: 60% here. This vehicle pulls
# out of the pump at 66%, just over that line, and does not go back until 44%,
# well under it. Those two numbers set the two things that matter to a demo:
# the vehicle spends ~15 minutes below the line, which is how long its alert
# stays open and therefore how long there is to talk about it, and one lap of
# the band is ~23 minutes, which is what `critical_fleet` staggers across.
# Draining a tank from full to empty — what every vehicle used to do — puts an
# hour and a half between one alert and the next.
#
# The band cannot be tightened much below twelve points: the refuel pause holds
# fuel flat, which drags the consumption measured across the backend's
# twenty-sample window below the nominal rate, and the alert line slides out of
# the band. Measured at 55–63, the vehicle flickers or stops alerting entirely.
CRITICAL_REFUEL_AT = 44.0
CRITICAL_REFUEL_TO = 66.0

# How long the vehicle stands at the pump, at the default interval and pause.
# Only used to size the fleet below, so a non-default `--interval` shifts the
# stagger slightly rather than breaking it.
CRITICAL_PUMP_MINUTES = 1.5
CRITICAL_LAP_MINUTES = (
    (CRITICAL_REFUEL_TO - CRITICAL_REFUEL_AT) / CRITICAL_CONSUMPTION_PER_HOUR * 60
    + CRITICAL_PUMP_MINUTES
)

CRITICAL_PROFILE = VehicleProfile(
    label="critical",
    consumption_per_hour=CRITICAL_CONSUMPTION_PER_HOUR,
    refuel_at=CRITICAL_REFUEL_AT,
    refuel_to=CRITICAL_REFUEL_TO,
    # A tenth of the fleet-wide swing, and the difference between a demo and a
    # flicker. Autonomy falls through the one-hour line at 1.7% a minute, so a
    # vehicle crossing it spends minutes within a percent or two of the
    # threshold. At the fleet's ±15% per-tick swing, the consumption the
    # backend measures wanders further than that and the alert opens, closes
    # and reopens for several readings around every crossing. At ±3% the
    # crossing is decisive and the alert opens once and stays.
    consumption_jitter=0.03,
    # This vehicle does not stop, for the same reason. A single idle tick
    # collapses the measured rate to the idle one, the predicted autonomy jumps
    # back above an hour, and the alert that just fired resolves itself. A
    # vehicle driving a highway leg is also the situation being demonstrated: a
    # truck standing still is not burning its range down.
    idle_probability=0.0,
)

# When the first critical vehicle trips the rule. Long enough to log in and
# have the dashboard open before anything happens, short enough that nobody
# starts wondering whether the simulator is running.
CRITICAL_FIRST_ALERT_MINUTES = 3.0

# And how far apart the ones after it arrive.
CRITICAL_ALERT_SPACING_MINUTES = 2.0


def critical_fleet() -> tuple[VehicleProfile, ...]:
    """Critical vehicles staggered so their alerts arrive one at a time.

    A vehicle trips the rule when its tank falls to the alert line, so starting
    it `n` minutes' worth of fuel above that line puts its first alert `n`
    minutes into the run — and every lap of the refuel band after that. Cover
    one lap with vehicles spaced by the cadence and the fleet produces a steady
    stream of alerts rather than one burst and a long silence.

    Their starting tanks are exact rather than drawn from a range: the spacing
    is the whole point, and a random draw would collapse two vehicles onto the
    same minute often enough to be noticed.
    """
    per_minute = CRITICAL_CONSUMPTION_PER_HOUR / 60
    count = ceil(CRITICAL_LAP_MINUTES / CRITICAL_ALERT_SPACING_MINUTES)
    return tuple(
        replace(CRITICAL_PROFILE, fuel_min=tank, fuel_max=tank)
        for tank in (
            CRITICAL_CONSUMPTION_PER_HOUR
            + (CRITICAL_FIRST_ALERT_MINUTES + index * CRITICAL_ALERT_SPACING_MINUTES) * per_minute
            for index in range(count)
        )
    )


SCENARIOS: dict[str, tuple[VehicleProfile, ...]] = {
    # Everything the technical demo needs to show at once: a working fleet, a
    # steady stream of predictive alerts, and one of each special state.
    "demo": (
        VehicleProfile(label="normal", count=3),
        *critical_fleet(),
        NO_SIGNAL_PROFILE,
        INACTIVE_PROFILE,
    ),
    # Just the alerting path, for when the point is the rule and not the fleet.
    "critical": (
        VehicleProfile(label="normal", count=1),
        *critical_fleet(),
    ),
}

#: Resolved from `device_count` rather than listed here, so `--devices` keeps
#: meaning what it always meant when no scenario is named.
DEFAULT_SCENARIO = "default"


def scenario_names() -> list[str]:
    return [DEFAULT_SCENARIO, *sorted(SCENARIOS)]


def profiles_from_dicts(raw: Any) -> tuple[VehicleProfile, ...]:
    """Builds profiles from the `profiles` key of a `--config` JSON file.

    Unknown keys are rejected rather than ignored: a typo in a config file that
    silently produces the default fleet is exactly the kind of thing that gets
    noticed halfway through a demo.
    """
    if not isinstance(raw, list) or not raw:
        raise ValueError("'profiles' must be a non-empty list of objects")

    known = {field.name for field in fields(VehicleProfile)}
    profiles = []
    for entry in raw:
        if not isinstance(entry, dict):
            raise ValueError("each entry in 'profiles' must be an object")
        unknown = set(entry) - known
        if unknown:
            raise ValueError(f"unknown profile keys: {', '.join(sorted(unknown))}")
        if "label" not in entry:
            raise ValueError("each profile needs a 'label'")
        profiles.append(VehicleProfile(**entry))
    return tuple(profiles)


def resolve(
    scenario: str, device_count: int, profiles: tuple[VehicleProfile, ...] | None
) -> tuple[VehicleProfile, ...]:
    """The fleet composition to build, in precedence order.

    Explicit profiles from a config file win over a named scenario, which wins
    over the plain `--devices` fleet — same lowest-to-highest ordering the rest
    of the configuration follows.
    """
    if profiles is not None:
        return profiles
    if scenario == DEFAULT_SCENARIO:
        return (VehicleProfile(label="normal", count=device_count),)
    try:
        return SCENARIOS[scenario]
    except KeyError:
        raise ValueError(
            f"unknown scenario '{scenario}': choose one of {', '.join(scenario_names())}"
        ) from None


def expand(profiles: tuple[VehicleProfile, ...]) -> list[VehicleProfile]:
    """One profile per vehicle, in declaration order.

    Vehicles are numbered off this list, so a given scenario and seed always
    put the same profile behind the same device code.
    """
    return [
        profile if profile.count == 1 else replace(profile, count=1)
        for profile in profiles
        for _ in range(profile.count)
    ]
