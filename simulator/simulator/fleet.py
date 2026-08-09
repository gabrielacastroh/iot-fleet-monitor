"""Wires a config into N concurrently running vehicles. One asyncio task per
vehicle — this is all I/O-bound HTTP, so threads would only add overhead.
"""

from __future__ import annotations

import asyncio
import logging
import random
import time

import httpx

from simulator.client import FleetClient, SimulatorError
from simulator.config import SimulatorConfig
from simulator.scenarios import expand
from simulator.vehicle import VehicleState, new_vehicle, tick

logger = logging.getLogger("simulator.fleet")


def vehicle_rng(seed: int | None, index: int, stream: str = "tick") -> random.Random:
    """One generator per vehicle per purpose, derived from the run's seed.

    Vehicles run as concurrent tasks, so a single shared generator would hand
    out draws in whatever order the event loop happened to resume them — the
    run would differ every time even with a seed. Deriving a stream per vehicle
    is what makes `--seed` mean something.

    `stream` separates a vehicle's setup draws from its driving draws, so the
    two cannot replay the same numbers at each other.
    """
    return random.Random(f"{seed}:{index}:{stream}") if seed is not None else random.Random()


def build_fleet(config: SimulatorConfig) -> list[VehicleState]:
    """The vehicles this configuration describes, numbered in profile order."""
    profiles = expand(config.fleet_profiles())
    return [
        new_vehicle(index, config, vehicle_rng(config.seed, index, "init"), profile)
        for index, profile in enumerate(profiles)
    ]


async def run(config: SimulatorConfig) -> None:
    logging.basicConfig(
        level=config.log_level, format="%(asctime)s %(levelname)-7s %(message)s", datefmt="%H:%M:%S"
    )

    vehicles = build_fleet(config)
    # Its own stream, so adding or removing a vehicle does not shift the draws
    # every other vehicle gets.
    startup_rng = vehicle_rng(config.seed, -1, "startup")

    async with httpx.AsyncClient(base_url=config.base_url, timeout=10.0) as http:
        client = FleetClient(http)
        await client.login(config.email, config.password)
        logger.info("Logged in as %s", config.email)

        # Sequential on purpose: this only runs once at startup for a handful
        # of devices, and it keeps "create if missing" free of the race a
        # concurrent gather would introduce against itself.
        device_ids: dict[str, str] = {}
        for vehicle in vehicles:
            device_ids[vehicle.device_code] = await client.ensure_device(
                vehicle.device_code,
                vehicle.vehicle_name,
                vehicle.plate,
                is_active=vehicle.profile.is_active,
            )
            logger.info(
                "%-10s | profile=%-9s fuel=%5.1f%%  burn=%5.1f%%/h  %s",
                vehicle.device_code,
                vehicle.profile.label,
                vehicle.fuel_level,
                vehicle.consumption_per_hour,
                _reporting_note(vehicle),
            )
        logger.info(
            "Fleet ready: %d vehicle(s), scenario '%s', seed %s, every %.0fs to %s",
            len(vehicles),
            config.scenario if config.profiles is None else "custom",
            config.seed if config.seed is not None else "random",
            config.interval_seconds,
            config.base_url,
        )

        tasks = [
            asyncio.create_task(
                _run_vehicle(
                    client,
                    device_ids[vehicle.device_code],
                    vehicle,
                    config,
                    vehicle_rng(config.seed, index),
                    startup_rng.uniform(0, config.jitter_seconds),
                )
            )
            for index, vehicle in enumerate(vehicles)
        ]

        try:
            if config.duration_seconds is not None:
                await asyncio.wait_for(_wait_all(tasks), timeout=config.duration_seconds)
            else:
                await _wait_all(tasks)
        except asyncio.TimeoutError:
            logger.info("Duration elapsed (%.0fs), stopping fleet", config.duration_seconds)
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)


async def _wait_all(tasks: list[asyncio.Task]) -> None:
    await asyncio.gather(*tasks)


def _reporting_note(vehicle: VehicleState) -> str:
    silent_after = vehicle.profile.silent_after_ticks
    if silent_after is None:
        return "reporting"
    if silent_after == 0:
        return "registered, never reports"
    return f"reports {silent_after} reading(s), then goes silent"


async def _run_vehicle(
    client: FleetClient,
    device_id: str,
    state: VehicleState,
    config: SimulatorConfig,
    rng: random.Random,
    startup_delay: float,
) -> None:
    # Each vehicle starts on its own offset so a fleet of N devices does not
    # hammer the backend in lockstep. Applied once: adding it to every cycle
    # made the real interval drift above the configured one.
    silent_after = state.profile.silent_after_ticks
    if silent_after == 0:
        logger.info("%-10s | registered but silent by profile", state.device_code)
        return

    await asyncio.sleep(startup_delay)

    sent = 0
    while True:
        start = time.monotonic()
        sample = tick(state, config, config.interval_seconds / 3600, rng)

        try:
            await client.post_telemetry(device_id, sample)
            logger.info(
                "%-10s | speed=%5.1f km/h  fuel=%5.1f%%  temp=%5.1f°C",
                state.device_code,
                sample.speed,
                sample.fuel_level,
                sample.temperature,
            )
        except SimulatorError as exc:
            logger.warning("%-10s | send failed: %s", state.device_code, exc)
        except httpx.HTTPError as exc:
            logger.warning("%-10s | network error: %s", state.device_code, exc)

        sent += 1
        if silent_after is not None and sent >= silent_after:
            logger.info(
                "%-10s | going silent after %d reading(s) by profile", state.device_code, sent
            )
            return

        elapsed = time.monotonic() - start
        await asyncio.sleep(max(config.interval_seconds - elapsed, 0.0))
