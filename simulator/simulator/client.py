"""All backend-contract knowledge lives here: request shapes, auth headers,
status codes. Nothing else in this simulator imports httpx directly, so a
change to how the backend is called stays in one file.
"""

from __future__ import annotations

from dataclasses import asdict

import httpx

from simulator.vehicle import TelemetrySample


class SimulatorError(Exception):
    """Raised for failures the simulator cannot recover from on its own — the
    caller's job is to report this and stop, not retry forever."""


class FleetClient:
    def __init__(self, http: httpx.AsyncClient) -> None:
        self._http = http
        self._token: str | None = None
        self._email = ""
        self._password = ""

    async def login(self, email: str, password: str) -> None:
        self._email, self._password = email, password
        await self._refresh_token()

    async def _refresh_token(self) -> None:
        # OAuth2PasswordRequestForm on the backend expects form-encoded
        # `username`/`password`, not JSON — same shape the frontend's login
        # form sends.
        response = await self._http.post(
            "/auth/login", data={"username": self._email, "password": self._password}
        )
        if response.status_code != 200:
            raise SimulatorError(
                f"Login failed ({response.status_code}): check --email/--password. {response.text}"
            )
        self._token = response.json()["access_token"]

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._token}"}

    async def ensure_device(
        self, device_code: str, vehicle_name: str, plate: str, *, is_active: bool = True
    ) -> str:
        """Reuses a device already registered under this code; creates one
        otherwise. Creation needs admin credentials — once the fleet exists,
        posting telemetry works with any authenticated account."""
        existing = await self._find_device(device_code)
        if existing is not None:
            # A reused device carries whatever `is_active` the previous run
            # left on it, so the second run of a scenario would show its
            # "inactive" vehicle as active. Reconciling here is what keeps a
            # seeded scenario reproducible across runs.
            await self._sync_is_active(existing, is_active)
            return existing["id"]

        response = await self._http.post(
            "/devices",
            json={
                "vehicle_name": vehicle_name,
                "device_code": device_code,
                "plate": plate,
                "is_active": is_active,
            },
            headers=self._headers(),
        )
        if response.status_code == 201:
            return response.json()["id"]
        if response.status_code == 409:
            # Lost a race with another simulator instance creating the same
            # device — the row exists now, so just look it up.
            existing = await self._find_device(device_code)
            if existing is not None:
                return existing["id"]
        if response.status_code == 403:
            raise SimulatorError(
                f"Cannot create device '{device_code}': this account is not an admin. "
                "Run with admin credentials, or pre-create the devices this simulator expects."
            )
        raise SimulatorError(
            f"Could not create device '{device_code}': {response.status_code} {response.text}"
        )

    async def _sync_is_active(self, device: dict, is_active: bool) -> None:
        if device.get("is_active", True) == is_active:
            return
        response = await self._http.patch(
            f"/devices/{device['id']}", json={"is_active": is_active}, headers=self._headers()
        )
        if response.status_code != 200:
            raise SimulatorError(
                f"Could not update device '{device['id']}': "
                f"{response.status_code} {response.text}"
            )

    async def _find_device(self, device_code: str) -> dict | None:
        """The whole device row, not just its id: `ensure_device` also has to
        compare what is already registered against what the profile asks for.

        Note this matches on `device_code`, which `GET /devices` masks for
        non-admin accounts — one more reason the simulator needs an admin.
        """
        response = await self._http.get("/devices", headers=self._headers())
        if response.status_code != 200:
            raise SimulatorError(f"Could not list devices: {response.status_code} {response.text}")
        for device in response.json():
            if device["device_code"] == device_code:
                return device
        return None

    async def post_telemetry(self, device_id: str, sample: TelemetrySample) -> None:
        payload = {"device_id": device_id, **asdict(sample)}
        response = await self._http.post("/telemetry", json=payload, headers=self._headers())

        if response.status_code == 401:
            # The access token expired mid-run — a real risk over the length
            # of a live demo. One silent re-login, then retry once.
            await self._refresh_token()
            response = await self._http.post("/telemetry", json=payload, headers=self._headers())

        if response.status_code != 201:
            raise SimulatorError(f"POST /telemetry failed: {response.status_code} {response.text}")
