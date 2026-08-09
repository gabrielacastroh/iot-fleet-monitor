"""The simulator against the backend's real predictive fuel rule.

These are the tests that answer the question the simulator exists for: can it
create the conditions that make the backend raise a LOW_FUEL alert, once,
within the time a demo has? They drive the real `FuelService` and replay
`AlertService.sync_fuel_alert`'s transitions, so nothing here can pass by
re-implementing the rule more favourably than the backend applies it.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import pytest

from simulator.config import SimulatorConfig
from simulator.fleet import build_fleet, vehicle_rng
from simulator.scenarios import SCENARIOS, VehicleProfile, expand
from simulator.vehicle import new_vehicle, tick

fuel_service = pytest.importorskip(
    "app.services.fuel_service", reason="backend sources not available next to the simulator"
)
FuelService = fuel_service.FuelService
PredictionStatus = fuel_service.PredictionStatus

# Mirrors telemetry_service.FUEL_HISTORY_SAMPLES. Imported by value rather than
# by reference because that module pulls in SQLAlchemy, which the simulator
# deliberately does not depend on.
FUEL_HISTORY_SAMPLES = 20


@dataclass(frozen=True)
class _Reading:
    """What `AverageConsumptionStrategy` reads off a stored reading."""

    fuel_level: float
    recorded_at: datetime


@dataclass
class _Run:
    created_at_minutes: list[float]
    resolved_at_minutes: list[float]
    readings: list[_Reading]

    @property
    def created(self) -> int:
        return len(self.created_at_minutes)

    @property
    def resolved(self) -> int:
        return len(self.resolved_at_minutes)

    @property
    def first_alert_minutes(self) -> float | None:
        return self.created_at_minutes[0] if self.created_at_minutes else None

    @property
    def gaps_minutes(self) -> list[float]:
        """How long the vehicle went without an open alert between two of them."""
        return [
            opened - closed
            for opened, closed in zip(self.created_at_minutes[1:], self.resolved_at_minutes)
        ]

    @property
    def open_minutes(self) -> list[float]:
        """How long each alert stayed open before it resolved."""
        return [
            closed - opened
            for opened, closed in zip(self.created_at_minutes, self.resolved_at_minutes)
        ]


def _ingest(vehicle, config: SimulatorConfig, minutes: float, rng) -> _Run:
    """Drives one vehicle and feeds every reading through the backend's rule.

    `recorded_at` is stamped by the server in the real flow, so it advances by
    the wall-clock interval here — the simulator has no say over it, which is
    exactly why the alert cannot be reached by simulating time faster.
    """
    start = datetime.now(timezone.utc)
    interval = config.interval_seconds

    readings = [
        _Reading(
            tick(vehicle, config, interval / 3600, rng).fuel_level,
            start + timedelta(seconds=index * interval),
        )
        for index in range(int(minutes * 60 / interval))
    ]
    return _replay(readings, interval)


def _replay(readings: list[_Reading], interval_seconds: float) -> _Run:
    """The alert lifecycle a stored series of readings produces."""
    service = FuelService()
    run = _Run(created_at_minutes=[], resolved_at_minutes=[], readings=readings)
    alert_open = False

    for index in range(len(readings)):
        window = readings[max(0, index + 1 - FUEL_HISTORY_SAMPLES) : index + 1]
        prediction = service.evaluate(window)
        elapsed_minutes = (index + 1) * interval_seconds / 60

        # AlertService.sync_fuel_alert: raise on should_alert (deduplicated
        # against the open one), auto-resolve only on a measured, safe autonomy.
        if prediction.should_alert:
            if not alert_open:
                run.created_at_minutes.append(elapsed_minutes)
                alert_open = True
        elif alert_open and prediction.status is PredictionStatus.OK:
            run.resolved_at_minutes.append(elapsed_minutes)
            alert_open = False

    return run


def _config(**overrides) -> SimulatorConfig:
    return SimulatorConfig(email="a@a.com", password="x", **overrides)


def _critical_vehicle(config: SimulatorConfig, seed: int):
    profile = next(p for p in expand(SCENARIOS["demo"]) if p.label == "critical")
    return new_vehicle(0, config, vehicle_rng(seed, 0, "init"), profile)


def _fleet_alert_minutes(config: SimulatorConfig, seed: int, minutes: float) -> list[float]:
    """Every alert the demo fleet raises, in the order a reviewer sees them."""
    times: list[float] = []
    for index, vehicle in enumerate(build_fleet(config)):
        # Silent and inactive vehicles never post, so they cannot be predicted on.
        if vehicle.profile.silent_after_ticks == 0:
            continue
        run = _ingest(vehicle, config, minutes=minutes, rng=vehicle_rng(seed, index))
        times += run.created_at_minutes
    return sorted(times)


# The demo's whole promise, both halves of it: nothing fires while the reviewer
# is still logging in, and the first alert lands before anyone starts wondering
# whether the simulator is running at all.
MIN_MINUTES_TO_FIRST_ALERT = 2.0
MAX_MINUTES_TO_FIRST_ALERT = 5.0

# And then they keep coming, one at a time. The critical vehicles are staggered
# across one lap of their refuel band, so the fleet raises an alert every couple
# of minutes rather than in bursts with a quarter of an hour of silence between.
MAX_MINUTES_BETWEEN_FLEET_ALERTS = 7.0
MAX_MEAN_MINUTES_BETWEEN_FLEET_ALERTS = 3.0


@pytest.mark.parametrize("seed", [1, 7, 42, 99, 2024])
def test_the_first_alert_lands_once_the_reviewer_has_logged_in(seed):
    config = _config(seed=seed, scenario="demo")

    first = _fleet_alert_minutes(config, seed, minutes=15)[0]

    assert MIN_MINUTES_TO_FIRST_ALERT <= first <= MAX_MINUTES_TO_FIRST_ALERT


@pytest.mark.parametrize("seed", [1, 7, 42, 99, 2024])
def test_the_fleet_raises_an_alert_every_couple_of_minutes(seed):
    config = _config(seed=seed, scenario="demo")

    times = _fleet_alert_minutes(config, seed, minutes=90)
    gaps = [later - earlier for earlier, later in zip(times, times[1:])]

    assert max(gaps) <= MAX_MINUTES_BETWEEN_FLEET_ALERTS, f"quiet stretch in {times}"
    assert sum(gaps) / len(gaps) <= MAX_MEAN_MINUTES_BETWEEN_FLEET_ALERTS


# A demo that shows the alert lifecycle needs alerts to keep arriving, not one
# at minute zero and silence after it. The critical vehicle refuels just under
# the alert line and leaves the pump just over it, so it laps that band a few
# times an hour.
MAX_MINUTES_BETWEEN_ALERTS = 25.0

# What separates that cadence from the flapping regression below: an alert has
# to stay open long enough to be seen and clicked, and the quiet stretch after
# it has to be a real drain cycle rather than the next reading changing its
# mind. A lap of the band is ~14 minutes of driving, so both halves of it are
# minutes, not seconds.
MIN_MINUTES_ALERT_STAYS_OPEN = 2.0
MIN_MINUTES_BETWEEN_ALERTS = 2.0


@pytest.mark.parametrize("seed", [1, 7, 42, 99, 2024])
def test_the_critical_vehicle_keeps_producing_alerts(seed):
    """One alert at startup is not a demo of a predictive rule — the reviewer
    has to be able to watch one open, close and open again."""
    config = _config(seed=seed, scenario="demo")
    vehicle = _critical_vehicle(config, seed)

    run = _ingest(vehicle, config, minutes=60, rng=vehicle_rng(seed, 0))

    assert run.created >= 3, f"only {run.created} alerts in an hour: {run.created_at_minutes}"
    for gap in run.gaps_minutes:
        assert gap <= MAX_MINUTES_BETWEEN_ALERTS


@pytest.mark.parametrize("seed", [1, 7, 42, 99, 2024])
def test_the_alert_lifecycle_is_a_drain_cycle_and_not_a_flicker(seed):
    """The regression this profile has to keep clear of.

    Reporting fuel at one decimal quantised the drop across the backend's
    twenty-sample window so coarsely that the consumption it measured could
    only land on a couple of discrete values, and those straddled the one-hour
    threshold. The result was a create/resolve cycle every few readings — 38
    alerts in an hour for a single low tank. Cycling faster on purpose is only
    legitimate while every open and every quiet stretch still lasts minutes.
    """
    config = _config(seed=seed, scenario="demo")
    vehicle = _critical_vehicle(config, seed)

    run = _ingest(vehicle, config, minutes=60, rng=vehicle_rng(seed, 0))

    for open_for in run.open_minutes:
        assert open_for >= MIN_MINUTES_ALERT_STAYS_OPEN, f"alert blinked: {run.created_at_minutes}"
    for gap in run.gaps_minutes:
        assert gap >= MIN_MINUTES_BETWEEN_ALERTS, f"alert flickered back: {run.created_at_minutes}"


def test_refuelling_resolves_the_open_alert():
    """The other half of the lifecycle: a recovered autonomy closes the alert,
    and it closes once per drain cycle rather than on every reading."""
    config = _config(seed=42, scenario="demo")
    vehicle = _critical_vehicle(config, 42)

    run = _ingest(vehicle, config, minutes=60, rng=vehicle_rng(42, 0))

    assert run.resolved >= 1
    assert run.resolved_at_minutes[0] > run.created_at_minutes[0]
    # Never two closes for one open: the alert opens, closes, and only then
    # opens again.
    assert run.created - run.resolved in (0, 1)


@pytest.mark.parametrize("seed", [1, 42, 2024])
def test_normal_vehicles_never_alert_during_a_demo(seed):
    """A fleet where everything alerts proves nothing about the rule."""
    config = _config(seed=seed, scenario="demo")
    profile = next(p for p in expand(SCENARIOS["demo"]) if p.label == "normal")
    vehicle = new_vehicle(0, config, vehicle_rng(seed, 0, "init"), profile)

    run = _ingest(vehicle, config, minutes=60, rng=vehicle_rng(seed, 0))

    assert run.created == 0


def test_coarse_fuel_reporting_is_what_caused_the_flapping():
    """Pins the root cause, so rounding cannot quietly come back.

    Same vehicle, same drive; the only difference is the precision the reading
    is reported at. Quantise the drop coarsely enough and the consumption the
    backend measures across its window can only land on a couple of values —
    which straddle the threshold, so the alert blinks instead of tracking a
    drain.
    """
    config = _config(seed=42, scenario="demo")
    run = _ingest(_critical_vehicle(config, 42), config, minutes=60, rng=vehicle_rng(42, 0))

    coarse = _replay(
        [_Reading(round(r.fuel_level, 0), r.recorded_at) for r in run.readings],
        config.interval_seconds,
    )

    assert min(run.open_minutes) >= MIN_MINUTES_ALERT_STAYS_OPEN
    assert min(coarse.open_minutes) < MIN_MINUTES_ALERT_STAYS_OPEN


def test_only_the_critical_vehicles_alert_across_the_demo_fleet():
    """End to end over the composition SETUP.md tells the reviewer to run."""
    config = _config(seed=42, scenario="demo")

    # Long enough for the last vehicle in the stagger to reach the line: the
    # fleet covers one lap of the band, so the tail of it alerts a lap in.
    runs = [
        (vehicle.profile.label, _ingest(vehicle, config, minutes=35, rng=vehicle_rng(42, index)))
        for index, vehicle in enumerate(build_fleet(config))
        # Silent and inactive vehicles never post, so they cannot be predicted on.
        if vehicle.profile.silent_after_ticks != 0
    ]

    alerting = {label for label, run in runs if run.created}
    assert alerting == {"critical"}, f"unexpected profiles alerting: {alerting}"
    assert all(run.created for label, run in runs if label == "critical")


@pytest.mark.parametrize("seed", [1, 42])
def test_every_reported_fuel_level_stays_within_the_backend_schema(seed):
    """TelemetryReadingCreate declares fuel_level ge=0 le=100; anything outside
    is a 422 mid-demo."""
    config = _config(seed=seed, scenario="demo")
    for index, vehicle in enumerate(build_fleet(config)):
        run = _ingest(vehicle, config, minutes=90, rng=vehicle_rng(seed, index))
        assert all(0.0 <= reading.fuel_level <= 100.0 for reading in run.readings)
