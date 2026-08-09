# Tests del módulo de alertas: contrato HTTP, acceso solo-admin, y la
# política que decide cuándo abrir/cerrar una alerta según la predicción de combustible.

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.models.alert import Alert, AlertType
from app.schemas.alert import AlertCreate, AlertFilters, AlertQuery
from app.services.alert_service import AlertService, alert_service
from app.services.fuel_service import FuelPrediction, PredictionStatus
from app.websocket.events import AlertCreatedEvent, AlertResolvedEvent, DomainEvent

READING = {
    "latitude": 4.65,
    "longitude": -74.05,
    "speed": 62.5,
    "fuel_level": 45.0,
    "temperature": 89.0,
}


# Crea un dispositivo de prueba vía la API, con datos por defecto que se pueden sobreescribir.
async def _create_device(async_client, admin_headers, **overrides) -> dict:
    payload = {"vehicle_name": "Truck 1", "device_code": "DEV-1", "plate": "ABC123"}
    response = await async_client.post(
        "/devices", json={**payload, **overrides}, headers=admin_headers
    )
    assert response.status_code == 201, response.text
    return response.json()


# Arma una predicción de combustible a mano, para probar las alertas sin
# depender del cálculo real de fuel_service.
def _prediction(
    *,
    status: PredictionStatus = PredictionStatus.OK,
    hours_remaining: float | None,
    should_alert: bool,
    fuel_level: float = 10.0,
) -> FuelPrediction:
    return FuelPrediction(
        status=status,
        fuel_level=fuel_level,
        consumption_per_hour=25.0 if hours_remaining else None,
        hours_remaining=hours_remaining,
        should_alert=should_alert,
    )


# Predicciones reutilizables: una crítica (dispara alerta) y una segura (no dispara).
CRITICAL = _prediction(hours_remaining=0.4, should_alert=True)
SAFE = _prediction(hours_remaining=8.0, should_alert=False, fuel_level=80.0)


# Abre una alerta de combustible bajo para un dispositivo, usando la predicción crítica.
async def _open_alert(db_session, device_id: uuid.UUID) -> Alert:
    alert = await alert_service.sync_fuel_alert(db_session, device_id, CRITICAL)
    assert alert is not None
    return alert


# --------------------------------------------------------------------------
# Control de acceso
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_alerts_require_authentication(async_client):
    assert (await async_client.get("/alerts")).status_code == 401
    assert (await async_client.get(f"/alerts/{uuid.uuid4()}")).status_code == 401
    assert (await async_client.patch(f"/alerts/{uuid.uuid4()}/resolve")).status_code == 401


@pytest.mark.asyncio
# Las alertas exponen el estado operativo de toda la flota, por eso un
# usuario normal no puede leerlas aunque sí pueda leer devices y telemetría.
async def test_alerts_are_admin_only(async_client, user_headers):
    assert (await async_client.get("/alerts", headers=user_headers)).status_code == 403
    assert (
        await async_client.get(f"/alerts/{uuid.uuid4()}", headers=user_headers)
    ).status_code == 403
    assert (
        await async_client.patch(f"/alerts/{uuid.uuid4()}/resolve", headers=user_headers)
    ).status_code == 403


# --------------------------------------------------------------------------
# Política de alertas
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_critical_autonomy_opens_an_alert(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)

    alert = await _open_alert(db_session, uuid.UUID(device["id"]))

    assert alert.alert_type is AlertType.LOW_FUEL
    assert alert.is_resolved is False
    assert "24 min" in alert.message


@pytest.mark.asyncio
async def test_safe_autonomy_never_opens_an_alert(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)

    assert await alert_service.sync_fuel_alert(db_session, uuid.UUID(device["id"]), SAFE) is None

    stored = await alert_service.list_alerts(db_session, AlertQuery())
    assert stored == []


@pytest.mark.asyncio
# Un camión quedándose sin combustible reporta cada pocos segundos. Debe
# quedar UNA alerta abierta por dispositivo, o la lista se inundaría justo cuando más importa.
async def test_repeated_critical_readings_do_not_duplicate_the_alert(
    async_client, admin_headers, db_session
):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])

    first = await _open_alert(db_session, device_id)
    second = await alert_service.sync_fuel_alert(db_session, device_id, CRITICAL)

    assert second is not None
    assert second.id == first.id
    assert len(await alert_service.list_alerts(db_session, AlertQuery())) == 1


@pytest.mark.asyncio
async def test_recovered_autonomy_resolves_the_alert(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])
    alert = await _open_alert(db_session, device_id)

    assert await alert_service.sync_fuel_alert(db_session, device_id, SAFE) is None

    await db_session.refresh(alert)
    assert alert.is_resolved is True


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status",
    [PredictionStatus.NO_CONSUMPTION, PredictionStatus.INSUFFICIENT_DATA],
)
# No alertar no es lo mismo que estar bien. Un camión parado reporta
# NO_CONSUMPTION y uno que se reconecta reporta INSUFFICIENT_DATA; ninguno de
# los dos significa que se cargó combustible, así que la alerta debe seguir abierta.
async def test_a_blind_prediction_does_not_resolve_the_alert(
    async_client, admin_headers, db_session, status
):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])
    alert = await _open_alert(db_session, device_id)

    still_open = await alert_service.sync_fuel_alert(
        db_session,
        device_id,
        _prediction(status=status, hours_remaining=None, should_alert=False),
    )

    assert still_open is not None
    assert still_open.id == alert.id
    assert still_open.is_resolved is False


@pytest.mark.asyncio
# La deduplicación solo mira alertas abiertas: un vehículo que se vuelve a
# quedar sin combustible después de cargar debe generar una alerta nueva, no reusar la cerrada.
async def test_a_resolved_alert_can_be_raised_again(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])

    first = await _open_alert(db_session, device_id)
    await alert_service.sync_fuel_alert(db_session, device_id, SAFE)
    second = await alert_service.sync_fuel_alert(db_session, device_id, CRITICAL)

    assert second is not None
    assert second.id != first.id


@pytest.mark.asyncio
async def test_alerts_of_different_devices_are_independent(
    async_client, admin_headers, db_session
):
    first = await _create_device(async_client, admin_headers)
    second = await _create_device(
        async_client, admin_headers, device_code="DEV-2", plate="XYZ789"
    )

    await _open_alert(db_session, uuid.UUID(first["id"]))
    await _open_alert(db_session, uuid.UUID(second["id"]))

    assert len(await alert_service.list_alerts(db_session, AlertQuery())) == 2


# --------------------------------------------------------------------------
# Integración con telemetría
# --------------------------------------------------------------------------


@pytest.mark.asyncio
# Prueba de punta a punta por el pipeline real: lectura -> predicción de
# combustible -> alerta, sin que el endpoint sepa nada de eso.
async def test_ingesting_a_critical_reading_raises_the_alert(
    async_client, admin_headers, db_session
):
    from app.models.telemetry import TelemetryReading
    from app.schemas.telemetry import TelemetryReadingCreate
    from app.services import telemetry_service

    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])

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

    assert ingestion.fuel.should_alert is True
    assert ingestion.alert is not None
    assert ingestion.alert.alert_type is AlertType.LOW_FUEL


@pytest.mark.asyncio
async def test_ingesting_a_healthy_reading_raises_nothing(
    async_client, admin_headers, db_session
):
    from app.schemas.telemetry import TelemetryReadingCreate
    from app.services import telemetry_service

    device = await _create_device(async_client, admin_headers)

    ingestion = await telemetry_service.record_reading(
        db_session,
        TelemetryReadingCreate(device_id=uuid.UUID(device["id"]), **READING),
    )

    assert ingestion.alert is None
    assert await alert_service.list_alerts(db_session, AlertQuery()) == []


# --------------------------------------------------------------------------
# Endpoints HTTP
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_alerts_returns_the_fleet(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    await _open_alert(db_session, uuid.UUID(device["id"]))

    response = await async_client.get("/alerts", headers=admin_headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["alert_type"] == "low_fuel"
    assert body[0]["device_id"] == device["id"]


@pytest.mark.asyncio
async def test_list_alerts_filters_by_resolution_state(
    async_client, admin_headers, db_session
):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])
    await _open_alert(db_session, device_id)
    await alert_service.sync_fuel_alert(db_session, device_id, SAFE)
    await alert_service.sync_fuel_alert(db_session, device_id, CRITICAL)

    open_only = await async_client.get(
        "/alerts", params={"is_resolved": "false"}, headers=admin_headers
    )
    resolved_only = await async_client.get(
        "/alerts", params={"is_resolved": "true"}, headers=admin_headers
    )

    assert len(open_only.json()) == 1
    assert len(resolved_only.json()) == 1


@pytest.mark.asyncio
# Por esto existe este endpoint: un badge armado sobre el listado leería su
# propio `limit` en vez de cuántas alertas están realmente abiertas.
async def test_count_alerts_sees_past_the_page_size(
    async_client, admin_headers, db_session
):
    devices = [
        await _create_device(
            async_client, admin_headers, device_code=f"DEV-{index}", plate=f"AAA{index:03d}"
        )
        for index in range(3)
    ]
    for device in devices:
        await _open_alert(db_session, uuid.UUID(device["id"]))

    paged = await async_client.get("/alerts", params={"limit": 1}, headers=admin_headers)
    assert len(paged.json()) == 1

    counted = await async_client.get("/alerts/count", headers=admin_headers)
    assert counted.status_code == 200
    assert counted.json() == {"count": 3}


@pytest.mark.asyncio
async def test_count_alerts_filters_by_resolution_state(
    async_client, admin_headers, db_session
):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])
    await _open_alert(db_session, device_id)
    await alert_service.sync_fuel_alert(db_session, device_id, SAFE)
    await alert_service.sync_fuel_alert(db_session, device_id, CRITICAL)

    open_only = await async_client.get(
        "/alerts/count", params={"is_resolved": "false"}, headers=admin_headers
    )
    resolved_only = await async_client.get(
        "/alerts/count", params={"is_resolved": "true"}, headers=admin_headers
    )

    assert open_only.json() == {"count": 1}
    assert resolved_only.json() == {"count": 1}


@pytest.mark.asyncio
# /alerts/{device_id} usa el mismo prefijo: si esa ruta se declarara antes,
# "count" se interpretaría como un device_id y respondería 422.
async def test_count_route_is_not_swallowed_by_the_device_route(
    async_client, admin_headers, user_headers
):
    assert (await async_client.get("/alerts/count", headers=admin_headers)).status_code == 200
    # El guard de admin también sigue aplicando acá.
    assert (await async_client.get("/alerts/count", headers=user_headers)).status_code == 403


@pytest.mark.asyncio
async def test_list_device_alerts_scopes_to_one_device(async_client, admin_headers, db_session):
    first = await _create_device(async_client, admin_headers)
    second = await _create_device(
        async_client, admin_headers, device_code="DEV-2", plate="XYZ789"
    )
    await _open_alert(db_session, uuid.UUID(first["id"]))
    await _open_alert(db_session, uuid.UUID(second["id"]))

    response = await async_client.get(f"/alerts/{first['id']}", headers=admin_headers)

    assert response.status_code == 200
    assert [alert["device_id"] for alert in response.json()] == [first["id"]]


@pytest.mark.asyncio
async def test_list_alerts_of_unknown_device_is_404(async_client, admin_headers):
    # Una lista vacía se leería como "este vehículo está bien", una respuesta
    # muy distinta de "este vehículo no existe".
    response = await async_client.get(f"/alerts/{uuid.uuid4()}", headers=admin_headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_resolve_endpoint_closes_the_alert(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    alert = await _open_alert(db_session, uuid.UUID(device["id"]))

    response = await async_client.patch(f"/alerts/{alert.id}/resolve", headers=admin_headers)

    assert response.status_code == 200
    assert response.json()["is_resolved"] is True


@pytest.mark.asyncio
# PATCH está pensado para poder repetirse: dos admins resolviendo la misma
# alerta al mismo tiempo es una carrera normal, no un error del cliente.
async def test_resolving_twice_is_idempotent(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    alert = await _open_alert(db_session, uuid.UUID(device["id"]))

    first = await async_client.patch(f"/alerts/{alert.id}/resolve", headers=admin_headers)
    second = await async_client.patch(f"/alerts/{alert.id}/resolve", headers=admin_headers)

    assert second.status_code == 200
    assert second.json() == first.json()


@pytest.mark.asyncio
async def test_resolving_an_unknown_alert_is_404(async_client, admin_headers):
    response = await async_client.patch(
        f"/alerts/{uuid.uuid4()}/resolve", headers=admin_headers
    )

    assert response.status_code == 404


# --------------------------------------------------------------------------
# Canal de eventos (publisher)
# --------------------------------------------------------------------------


@pytest.mark.asyncio
# Prueba el punto donde se conecta el canal de tiempo real: se inyecta un
# publisher de prueba y se verifica contra los tipos de evento reales.
async def test_publisher_receives_opened_and_resolved_events(
    async_client, admin_headers, db_session
):
    published: list[DomainEvent] = []

    class RecordingPublisher:
        async def publish(self, event: DomainEvent) -> None:
            published.append(event)

    service = AlertService(RecordingPublisher())
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])

    opened = await service.sync_fuel_alert(db_session, device_id, CRITICAL)
    assert opened is not None
    # Una alerta deduplicada no es un evento nuevo, no debe publicarse de nuevo.
    await service.sync_fuel_alert(db_session, device_id, CRITICAL)
    await service.sync_fuel_alert(db_session, device_id, SAFE)

    assert [type(event) for event in published] == [AlertCreatedEvent, AlertResolvedEvent]
    assert all(event.id == opened.id for event in published)
    assert published[0].message == opened.message


@pytest.mark.asyncio
# message es un String(255) en la base; si se truncara en silencio se
# perdería el motivo por el que se disparó la alerta.
async def test_message_length_is_rejected_before_it_reaches_the_column(
    async_client, admin_headers, db_session
):
    device = await _create_device(async_client, admin_headers)

    with pytest.raises(ValueError):
        AlertCreate(
            device_id=uuid.UUID(device["id"]),
            alert_type=AlertType.LOW_FUEL,
            message="x" * 256,
        )


@pytest.mark.asyncio
async def test_device_listing_accepts_filters(async_client, admin_headers, db_session):
    device = await _create_device(async_client, admin_headers)
    device_id = uuid.UUID(device["id"])
    await _open_alert(db_session, device_id)

    resolved = await alert_service.list_device_alerts(
        db_session, device_id, AlertFilters(is_resolved=True)
    )
    unresolved = await alert_service.list_device_alerts(
        db_session, device_id, AlertFilters(is_resolved=False)
    )

    assert resolved == []
    assert len(unresolved) == 1
