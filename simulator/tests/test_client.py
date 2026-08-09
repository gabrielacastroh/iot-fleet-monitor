"""FleetClient against a fake transport (httpx.MockTransport) — no real
server, but the actual request shapes the backend expects."""

import json

import httpx
import pytest

from simulator.client import FleetClient, SimulatorError
from simulator.vehicle import TelemetrySample


def _sample() -> TelemetrySample:
    return TelemetrySample(latitude=4.65, longitude=-74.05, speed=50.0, fuel_level=80.0, temperature=88.0)


async def test_login_sends_form_encoded_credentials():
    captured = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["content_type"] = request.headers["content-type"]
        captured["body"] = request.read().decode()
        return httpx.Response(200, json={"access_token": "tok123", "token_type": "bearer"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        await FleetClient(http).login("a@a.com", "secret")

    assert "application/x-www-form-urlencoded" in captured["content_type"]
    assert "username=a%40a.com" in captured["body"]


async def test_login_failure_raises_a_clear_error():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(401, json={"detail": "Incorrect email or password"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        with pytest.raises(SimulatorError):
            await FleetClient(http).login("a@a.com", "wrong")


async def test_ensure_device_reuses_an_existing_device_by_code():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.url.path == "/devices" and request.method == "GET":
            return httpx.Response(200, json=[{"id": "dev-1", "device_code": "SIM-001"}])
        raise AssertionError("must not create a device that already exists")

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        device_id = await client.ensure_device("SIM-001", "Truck 1", "ABC123")

    assert device_id == "dev-1"


async def test_ensure_device_creates_it_when_missing():
    calls: list[tuple[str, str]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append((request.method, request.url.path))
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.method == "GET":
            return httpx.Response(200, json=[])
        return httpx.Response(201, json={"id": "dev-new", "device_code": "SIM-002"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        device_id = await client.ensure_device("SIM-002", "Truck 2", "XYZ789")

    assert device_id == "dev-new"
    assert ("POST", "/devices") in calls


async def test_ensure_device_recovers_from_a_creation_race():
    """A 409 means another simulator instance won the race — the row exists
    now, so the client should just look it up instead of failing."""
    state = {"created": False}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.method == "GET":
            if state["created"]:
                return httpx.Response(200, json=[{"id": "dev-1", "device_code": "SIM-003"}])
            return httpx.Response(200, json=[])
        state["created"] = True
        return httpx.Response(409, json={"detail": {"field": "device_code", "message": "taken"}})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        device_id = await client.ensure_device("SIM-003", "Truck 3", "AAA111")

    assert device_id == "dev-1"


async def test_ensure_device_creation_forbidden_raises_a_clear_error():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.method == "GET":
            return httpx.Response(200, json=[])
        return httpx.Response(403, json={"detail": "Admin privileges required"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        with pytest.raises(SimulatorError, match="admin"):
            await client.ensure_device("SIM-004", "Truck 4", "BBB222")


async def test_ensure_device_registers_an_inactive_device_as_inactive():
    """"Inactivo" is a device-registry state, so it has to be set when the
    device is created — the telemetry contract has no field for it."""
    captured = {}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.method == "GET":
            return httpx.Response(200, json=[])
        captured["body"] = json.loads(request.read())
        return httpx.Response(201, json={"id": "dev-off", "device_code": "SIM-006"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        await client.ensure_device("SIM-006", "Truck 6", "SIM006", is_active=False)

    assert captured["body"]["is_active"] is False


async def test_ensure_device_reconciles_is_active_on_a_reused_device():
    """A second run of a seeded scenario has to look like the first. Without
    this, the vehicle registered as inactive stays active from the run before."""
    patched = {}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.method == "GET":
            return httpx.Response(
                200, json=[{"id": "dev-1", "device_code": "SIM-006", "is_active": True}]
            )
        if request.method == "PATCH":
            patched["path"] = request.url.path
            patched["body"] = json.loads(request.read())
            return httpx.Response(200, json={"id": "dev-1"})
        raise AssertionError("must not create a device that already exists")

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        device_id = await client.ensure_device("SIM-006", "Truck 6", "SIM006", is_active=False)

    assert device_id == "dev-1"
    assert patched["path"] == "/devices/dev-1"
    assert patched["body"] == {"is_active": False}


async def test_ensure_device_leaves_a_matching_device_untouched():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        if request.method == "GET":
            return httpx.Response(
                200, json=[{"id": "dev-1", "device_code": "SIM-001", "is_active": True}]
            )
        raise AssertionError("a device that already matches must not be written to")

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        assert await client.ensure_device("SIM-001", "Truck 1", "SIM001") == "dev-1"


async def test_post_telemetry_relogins_once_on_an_expired_token():
    telemetry_calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal telemetry_calls
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        telemetry_calls += 1
        if telemetry_calls == 1:
            return httpx.Response(401)
        return httpx.Response(201, json={"id": "reading-1"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        await client.post_telemetry("dev-1", _sample())  # must not raise

    assert telemetry_calls == 2


async def test_post_telemetry_sends_the_device_id_and_reading_fields():
    captured = {}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        captured["body"] = request.read()
        return httpx.Response(201, json={"id": "reading-1"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        await client.post_telemetry("dev-1", _sample())

    body = json.loads(captured["body"])
    assert body["device_id"] == "dev-1"
    assert body["fuel_level"] == 80.0


async def test_post_telemetry_failure_raises_a_clear_error():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth/login":
            return httpx.Response(200, json={"access_token": "tok"})
        return httpx.Response(422, json={"detail": "out of range"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://test") as http:
        client = FleetClient(http)
        await client.login("a@a.com", "x")
        with pytest.raises(SimulatorError):
            await client.post_telemetry("dev-1", _sample())
