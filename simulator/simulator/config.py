"""What to simulate and how, independent of where the settings come from.

Precedence, lowest to highest: dataclass defaults, a `--config` JSON file,
the `SIMULATOR_EMAIL`/`SIMULATOR_PASSWORD` environment variables, then CLI
flags. Credentials get their own environment override — the one setting that
should not sit in shell history or a committed config file.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass, fields
from pathlib import Path
from typing import Any

from simulator.scenarios import (
    DEFAULT_SCENARIO,
    VehicleProfile,
    profiles_from_dicts,
    resolve,
    scenario_names,
)


@dataclass(frozen=True, slots=True)
class SimulatorConfig:
    base_url: str = "http://localhost:8000"
    email: str = ""
    password: str = ""

    device_count: int = 5
    device_prefix: str = "SIM"

    #: Named fleet composition. `default` builds `device_count` ordinary
    #: vehicles; anything else comes from the scenario registry.
    scenario: str = DEFAULT_SCENARIO
    #: Set only from a `--config` file, and it overrides `scenario`.
    profiles: tuple[VehicleProfile, ...] | None = None

    #: Seeds every RNG the run uses. None means a different fleet each time;
    #: set it and the same flags reproduce the same run reading for reading.
    seed: int | None = None

    # Long enough that the backend's 20-sample fuel window spans ten minutes of
    # real driving. A shorter interval makes each window's fuel drop small
    # enough that sensor noise dominates the measured consumption rate, and the
    # predicted autonomy then oscillates across the one-hour threshold — which
    # is a stream of duplicate alerts, not a more responsive demo.
    interval_seconds: float = 30.0
    # Startup offset only, so a fleet of N devices does not hit the backend in
    # lockstep. It is not added to each cycle: that would make the real
    # interval drift above the configured one.
    jitter_seconds: float = 1.5

    speed_cruise_kmh: float = 60.0
    speed_variance_kmh: float = 8.0
    speed_max_kmh: float = 120.0
    idle_probability: float = 0.05

    fuel_consumption_per_hour: float = 9.0
    fuel_idle_consumption_per_hour: float = 0.5
    fuel_refuel_enabled: bool = True
    fuel_critical_threshold: float = 3.0
    fuel_refuel_pause_ticks: int = 3

    temperature_base: float = 85.0
    temperature_variance: float = 4.0

    center_latitude: float = 4.65
    center_longitude: float = -74.05
    radius_km: float = 15.0

    duration_seconds: float | None = None
    log_level: str = "INFO"

    def validate(self) -> None:
        if not self.email or not self.password:
            raise ValueError(
                "email and password are required: --email/--password, "
                "SIMULATOR_EMAIL/SIMULATOR_PASSWORD, or a --config file"
            )
        if self.device_count < 1:
            raise ValueError("device_count must be at least 1")
        if self.interval_seconds <= 0:
            raise ValueError("interval_seconds must be positive")
        if self.jitter_seconds < 0:
            raise ValueError("jitter_seconds cannot be negative")
        if self.fuel_critical_threshold < 0:
            raise ValueError("fuel_critical_threshold cannot be negative")

        # Raises on an unknown scenario name, so a typo fails at startup rather
        # than after the fleet has already logged in.
        for profile in self.fleet_profiles():
            profile.validate()

    def fleet_profiles(self) -> tuple[VehicleProfile, ...]:
        """The fleet composition this configuration describes."""
        return resolve(self.scenario, self.device_count, self.profiles)


def _load_file(path: str) -> dict[str, Any]:
    return json.loads(Path(path).read_text())


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="simulator",
        description="Simulates a fleet of vehicles sending telemetry to the IoT fleet monitor backend.",
    )
    parser.add_argument("--config", help="Path to a JSON file with any of these same settings")
    parser.add_argument("--base-url", dest="base_url", default=None)
    parser.add_argument("--email", default=None, help="Or set SIMULATOR_EMAIL")
    parser.add_argument("--password", default=None, help="Or set SIMULATOR_PASSWORD")
    parser.add_argument(
        "--devices", dest="device_count", type=int, default=None, help="How many vehicles to simulate"
    )
    parser.add_argument("--device-prefix", dest="device_prefix", default=None)
    parser.add_argument(
        "--scenario",
        default=None,
        help=f"Fleet composition to build: {', '.join(scenario_names())}",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Makes the run reproducible: same flags and same seed, same fleet",
    )
    parser.add_argument(
        "--interval", dest="interval_seconds", type=float, default=None, help="Seconds between readings"
    )
    parser.add_argument("--jitter", dest="jitter_seconds", type=float, default=None)
    parser.add_argument("--speed-cruise", dest="speed_cruise_kmh", type=float, default=None)
    parser.add_argument("--speed-max", dest="speed_max_kmh", type=float, default=None)
    parser.add_argument(
        "--fuel-rate",
        dest="fuel_consumption_per_hour",
        type=float,
        default=None,
        help="Percent of tank burned per hour at cruising speed",
    )
    parser.add_argument(
        "--no-refuel",
        dest="fuel_refuel_enabled",
        action="store_false",
        default=None,
        help="Let a vehicle sit at 0%% fuel instead of refuelling after the low-fuel pause",
    )
    parser.add_argument(
        "--center", dest="center", nargs=2, type=float, default=None, metavar=("LAT", "LON")
    )
    parser.add_argument("--radius-km", dest="radius_km", type=float, default=None)
    parser.add_argument(
        "--duration",
        dest="duration_seconds",
        type=float,
        default=None,
        help="Stop after this many seconds; omit to run until Ctrl+C",
    )
    parser.add_argument("--log-level", default=None)
    return parser


def load_config(argv: list[str] | None = None) -> SimulatorConfig:
    args = _build_parser().parse_args(argv)

    values: dict[str, Any] = {}
    if args.config:
        values.update(_load_file(args.config))

    # A config file is the only place a fleet can be described vehicle class by
    # vehicle class; the CLI just picks a named scenario.
    if "profiles" in values:
        values["profiles"] = profiles_from_dicts(values["profiles"])

    if os.environ.get("SIMULATOR_EMAIL"):
        values["email"] = os.environ["SIMULATOR_EMAIL"]
    if os.environ.get("SIMULATOR_PASSWORD"):
        values["password"] = os.environ["SIMULATOR_PASSWORD"]

    if args.center is not None:
        values["center_latitude"], values["center_longitude"] = args.center

    known_fields = {f.name for f in fields(SimulatorConfig)}
    for key, value in vars(args).items():
        if key in ("config", "center") or value is None:
            continue
        if key in known_fields:
            values[key] = value

    config = SimulatorConfig(**values)
    config.validate()
    return config
