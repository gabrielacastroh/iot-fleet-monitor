import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.models.telemetry import TelemetryReading

READING = {
    "latitude": 4.65,
    "longitude": -74.05,
    "speed": 62.5,
    "fuel_level": 45.0,
    "temperature": 89.0,
}


# Crea un dispositivo de prueba vía la API.
async def _create_device(async_client, admin_headers, **overrides) -> dict:
    payload = {"vehicle_name": "Truck 1", "device_code": "DEV-1", "plate": "ABC123"}
    response = await async_client.post(
        "/devices", json={**payload, **overrides}, headers=admin_headers
    )
    assert response.status_code == 201, response.text
    return response.json()


# Manda una lectura de telemetría de prueba vía la API.
async def _post_reading(async_client, admin_headers, device_id: str, **overrides) -> dict:
    response = await async_client.post(
        "/telemetry",
        json={"device_id": device_id, **READING, **overrides},
        headers=admin_headers,
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_telemetry_requires_authentication(async_client):
    assert (await async_client.get("/telemetry")).status_code == 401
    assert (await async_client.post("/telemetry", json={})).status_code == 401


@pytest.mark.asyncio
async def test_record_reading_updates_device_last_seen_at(
    async_client, admin_headers, user_headers
):
    device = await _create_device(async_client, admin_headers)
    assert device["last_seen_at"] is None

    reading = await _post_reading(async_client, admin_headers, device["id"])
    assert reading["device_id"] == device["id"]
    assert reading["fuel_level"] == 45.0

    # Guardar una lectura siempre debe actualizar el last_seen_at del dispositivo.
    refreshed = await async_client.get(f"/devices/{device['id']}", headers=user_headers)
    assert refreshed.json()["last_seen_at"] == reading["recorded_at"]


@pytest.mark.asyncio
async def test_record_reading_rejects_unknown_device(async_client, admin_headers):
    response = await async_client.post(
        "/telemetry",
        json={"device_id": str(uuid.uuid4()), **READING},
        headers=admin_headers,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_record_reading_validates_ranges(async_client, admin_headers):
    device = await _create_device(async_client, admin_headers)

    for field, value in [
        ("latitude", 91.0),
        ("longitude", -181.0),
        ("speed", -1.0),
        ("fuel_level", 101.0),
    ]:
        response = await async_client.post(
            "/telemetry",
            json={"device_id": device["id"], **READING, field: value},
            headers=admin_headers,
        )
        assert response.status_code == 422, f"{field}={value} should be rejected"


@pytest.mark.asyncio
async def test_list_readings_filters_by_device(async_client, admin_headers, user_headers):
    first = await _create_device(async_client, admin_headers)
    second = await _create_device(
        async_client, admin_headers, device_code="DEV-2", plate="XYZ789"
    )
    await _post_reading(async_client, admin_headers, first["id"])
    await _post_reading(async_client, admin_headers, second["id"])

    all_readings = await async_client.get("/telemetry", headers=user_headers)
    assert len(all_readings.json()) == 2

    filtered = await async_client.get(
        "/telemetry", params={"device_id": first["id"]}, headers=user_headers
    )
    assert [reading["device_id"] for reading in filtered.json()] == [first["id"]]


@pytest.mark.asyncio
async def test_list_readings_filters_by_date_range(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    now = datetime.now(timezone.utc)

    db_session.add_all(
        [
            TelemetryReading(
                device_id=uuid.UUID(device["id"]), **READING, recorded_at=now - timedelta(days=3)
            ),
            TelemetryReading(
                device_id=uuid.UUID(device["id"]), **READING, recorded_at=now - timedelta(hours=1)
            ),
        ]
    )
    await db_session.commit()

    recent = await async_client.get(
        "/telemetry",
        params={"start_date": (now - timedelta(days=1)).isoformat()},
        headers=admin_headers,
    )
    assert len(recent.json()) == 1

    old = await async_client.get(
        "/telemetry",
        params={"end_date": (now - timedelta(days=1)).isoformat()},
        headers=admin_headers,
    )
    assert len(old.json()) == 1


@pytest.mark.asyncio
# Por esto existe este endpoint: un contador armado sobre el listado leería
# su propio `limit` en vez de cuánta telemetría llegó en realidad.
async def test_count_readings_sees_past_the_page_size(
    async_client, admin_headers, user_headers, db_session
):
    device = await _create_device(async_client, admin_headers)
    now = datetime.now(timezone.utc)
    db_session.add_all(
        [
            TelemetryReading(
                device_id=uuid.UUID(device["id"]),
                **READING,
                recorded_at=now - timedelta(minutes=index),
            )
            for index in range(5)
        ]
    )
    await db_session.commit()

    paged = await async_client.get(
        "/telemetry", params={"limit": 2}, headers=user_headers
    )
    assert len(paged.json()) == 2

    counted = await async_client.get("/telemetry/count", headers=user_headers)
    assert counted.status_code == 200
    assert counted.json() == {"count": 5}


@pytest.mark.asyncio
async def test_count_readings_applies_the_same_filters_as_the_listing(
    async_client, admin_headers, db_session
):
    device = await _create_device(async_client, admin_headers)
    other = await _create_device(
        async_client, admin_headers, device_code="DEV-2", plate="XYZ789"
    )
    now = datetime.now(timezone.utc)
    db_session.add_all(
        [
            TelemetryReading(
                device_id=uuid.UUID(device["id"]), **READING, recorded_at=now - timedelta(days=3)
            ),
            TelemetryReading(
                device_id=uuid.UUID(device["id"]), **READING, recorded_at=now - timedelta(hours=1)
            ),
            TelemetryReading(
                device_id=uuid.UUID(other["id"]), **READING, recorded_at=now - timedelta(hours=1)
            ),
        ]
    )
    await db_session.commit()

    since_yesterday = await async_client.get(
        "/telemetry/count",
        params={"start_date": (now - timedelta(days=1)).isoformat()},
        headers=admin_headers,
    )
    assert since_yesterday.json() == {"count": 2}

    one_device = await async_client.get(
        "/telemetry/count", params={"device_id": device["id"]}, headers=admin_headers
    )
    assert one_device.json() == {"count": 2}


@pytest.mark.asyncio
async def test_count_readings_requires_authentication(async_client):
    assert (await async_client.get("/telemetry/count")).status_code == 401


@pytest.mark.asyncio
async def test_list_readings_rejects_inverted_range(async_client, admin_headers):
    now = datetime.now(timezone.utc)
    response = await async_client.get(
        "/telemetry",
        params={
            "start_date": now.isoformat(),
            "end_date": (now - timedelta(days=1)).isoformat(),
        },
        headers=admin_headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_history_returns_newest_first(async_client, admin_headers, user_headers):
    device = await _create_device(async_client, admin_headers)
    await _post_reading(async_client, admin_headers, device["id"], speed=10.0)
    await _post_reading(async_client, admin_headers, device["id"], speed=20.0)

    response = await async_client.get(
        f"/telemetry/{device['id']}/history", headers=user_headers
    )
    assert response.status_code == 200
    assert [reading["speed"] for reading in response.json()] == [20.0, 10.0]


@pytest.mark.asyncio
async def test_history_respects_limit(async_client, admin_headers):
    device = await _create_device(async_client, admin_headers)
    for speed in (10.0, 20.0, 30.0):
        await _post_reading(async_client, admin_headers, device["id"], speed=speed)

    response = await async_client.get(
        f"/telemetry/{device['id']}/history", params={"limit": 2}, headers=admin_headers
    )
    assert len(response.json()) == 2


@pytest.mark.asyncio
async def test_history_of_unknown_device_is_404(async_client, admin_headers):
    # Un dispositivo que no existe no debe responder una lista vacía — eso se
    # leería como "registrado pero sin lecturas", un problema totalmente distinto.
    response = await async_client.get(
        f"/telemetry/{uuid.uuid4()}/history", headers=admin_headers
    )
    assert response.status_code == 404


@pytest.mark.asyncio
# Confirma que ingestar una lectura calcula la predicción de combustible,
# aunque el endpoint todavía no la devuelva en la respuesta.
async def test_record_reading_runs_the_fuel_prediction(async_client, admin_headers, db_session):
    from app.schemas.telemetry import TelemetryReadingCreate
    from app.services import telemetry_service
    from app.services.fuel_service import PredictionStatus

    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])

    # Dos horas de historial gastando 10 puntos por hora, más una lectura nueva.
    now = datetime.now(timezone.utc)
    db_session.add_all(
        [
            TelemetryReading(
                device_id=device_id,
                **{**READING, "fuel_level": level},
                recorded_at=now - timedelta(hours=hours),
            )
            for hours, level in ((2, 25.0), (1, 15.0))
        ]
    )
    await db_session.commit()

    ingestion = await telemetry_service.record_reading(
        db_session,
        TelemetryReadingCreate(device_id=device_id, **{**READING, "fuel_level": 5.0}),
    )

    assert ingestion.reading.fuel_level == 5.0
    assert ingestion.fuel.status is PredictionStatus.OK
    # 20 puntos en 2 horas, quedan 5: media hora de autonomía.
    assert ingestion.fuel.hours_remaining == pytest.approx(0.5, rel=0.05)
    assert ingestion.fuel.should_alert is True


@pytest.mark.asyncio
async def test_first_reading_of_a_device_has_no_prediction(
    async_client, admin_headers, db_session
):
    from app.schemas.telemetry import TelemetryReadingCreate
    from app.services import telemetry_service
    from app.services.fuel_service import PredictionStatus

    device = await _create_device(async_client, admin_headers, device_code="DEV-9", plate="ZZZ999")

    ingestion = await telemetry_service.record_reading(
        db_session,
        TelemetryReadingCreate(device_id=uuid.UUID(device["id"]), **READING),
    )

    assert ingestion.fuel.status is PredictionStatus.INSUFFICIENT_DATA
    assert ingestion.fuel.should_alert is False


@pytest.mark.asyncio
async def test_latest_requires_authentication(async_client):
    assert (await async_client.get("/telemetry/latest")).status_code == 401


@pytest.mark.asyncio
async def test_latest_returns_one_reading_per_device(
    async_client, admin_headers, user_headers
):
    first = await _create_device(async_client, admin_headers)
    second = await _create_device(
        async_client, admin_headers, device_code="DEV-2", plate="XYZ789"
    )
    await _post_reading(async_client, admin_headers, first["id"], fuel_level=80.0)
    await _post_reading(async_client, admin_headers, first["id"], fuel_level=70.0)
    await _post_reading(async_client, admin_headers, second["id"], fuel_level=30.0)

    response = await async_client.get("/telemetry/latest", headers=user_headers)
    assert response.status_code == 200

    by_device = {reading["device_id"]: reading for reading in response.json()}
    assert len(by_device) == 2
    assert by_device[first["id"]]["fuel_level"] == 70.0
    assert by_device[second["id"]]["fuel_level"] == 30.0


@pytest.mark.asyncio
# El caso por el que existe /latest: GET /telemetry recorta las N lecturas
# más nuevas de TODA la flota, así que un dispositivo callado queda afuera,
# empujado por los que siguen reportando. Su último nivel de combustible
# conocido sigue siendo la respuesta correcta para ese vehículo, y /latest
# tiene que devolverlo sin importar hace cuánto se registró.
async def test_latest_keeps_devices_the_fleet_wide_window_drops(
    async_client, admin_headers, user_headers, db_session
):
    quiet = await _create_device(async_client, admin_headers)
    busy = await _create_device(
        async_client, admin_headers, device_code="DEV-2", plate="XYZ789"
    )
    now = datetime.now(timezone.utc)

    db_session.add(
        TelemetryReading(
            device_id=uuid.UUID(quiet["id"]),
            **{**READING, "fuel_level": 51.7},
            recorded_at=now - timedelta(hours=9),
        )
    )
    db_session.add_all(
        [
            TelemetryReading(
                device_id=uuid.UUID(busy["id"]),
                **READING,
                recorded_at=now - timedelta(seconds=seconds),
            )
            for seconds in range(5)
        ]
    )
    await db_session.commit()

    # El listado de toda la flota solo ve al dispositivo ruidoso...
    window = await async_client.get(
        "/telemetry", params={"limit": 3}, headers=user_headers
    )
    assert {reading["device_id"] for reading in window.json()} == {busy["id"]}

    # ...mientras /latest sigue reportando al callado, con 9 horas de atraso y todo.
    latest = await async_client.get("/telemetry/latest", headers=user_headers)
    by_device = {reading["device_id"]: reading for reading in latest.json()}
    assert set(by_device) == {quiet["id"], busy["id"]}
    assert by_device[quiet["id"]]["fuel_level"] == 51.7


@pytest.mark.asyncio
async def test_latest_omits_devices_that_never_reported(
    async_client, admin_headers, user_headers
):
    # Ausente, no en cero: la UI muestra "sin datos" para estos, y confundirlos
    # con el caso "atrasado pero conocido" es justo el bug que se está evitando.
    reporting = await _create_device(async_client, admin_headers)
    await _create_device(async_client, admin_headers, device_code="DEV-2", plate="XYZ789")
    await _post_reading(async_client, admin_headers, reporting["id"])

    response = await async_client.get("/telemetry/latest", headers=user_headers)
    assert [reading["device_id"] for reading in response.json()] == [reporting["id"]]
