# Tests de la forma de los eventos y del publisher, sin canal real: los
# eventos son datos simples, y el publisher se prueba contra un
# ConnectionManager falso en vez de sockets reales.

import uuid
from datetime import datetime, timezone

import pytest

from app.models.alert import Alert, AlertType
from app.models.telemetry import TelemetryReading
from app.websocket.events import AlertCreatedEvent, AlertResolvedEvent, TelemetryUpdatedEvent
from app.websocket.publisher import NullEventPublisher, WebSocketEventPublisher

DEVICE_ID = uuid.uuid4()
NOW = datetime(2026, 8, 7, 12, 0, tzinfo=timezone.utc)


def _reading() -> TelemetryReading:
    return TelemetryReading(
        id=uuid.uuid4(),
        device_id=DEVICE_ID,
        latitude=4.65,
        longitude=-74.05,
        speed=62.5,
        fuel_level=45.0,
        temperature=89.0,
        recorded_at=NOW,
    )


def _alert(*, is_resolved: bool = False) -> Alert:
    return Alert(
        id=uuid.uuid4(),
        device_id=DEVICE_ID,
        alert_type=AlertType.LOW_FUEL,
        message="Autonomía por debajo de una hora: quedan 24 min con 10.0% de combustible",
        is_resolved=is_resolved,
        created_at=NOW,
    )


# --------------------------------------------------------------------------
# Eventos
# --------------------------------------------------------------------------


def test_telemetry_updated_carries_the_reading_and_is_public():
    event = TelemetryUpdatedEvent.from_reading(_reading())
    message = event.to_message()

    assert event.admin_only is False
    assert message["type"] == "telemetry_updated"
    assert message["data"]["device_id"] == str(DEVICE_ID)
    assert message["data"]["fuel_level"] == 45.0
    assert message["data"]["recorded_at"] == NOW.isoformat()


def test_alert_created_is_admin_only():
    alert = _alert()
    event = AlertCreatedEvent.from_alert(alert)
    message = event.to_message()

    assert event.admin_only is True
    assert message["type"] == "alert_created"
    assert message["data"]["id"] == str(alert.id)
    assert message["data"]["alert_type"] == "low_fuel"
    assert message["data"]["message"] == alert.message


# El frontend solo necesita el id para sacar la alerta de la lista de
# abiertas; reenviar el motivo original sería peso muerto en cada cierre.
def test_alert_resolved_omits_the_message_and_is_admin_only():
    alert = _alert(is_resolved=True)
    event = AlertResolvedEvent.from_alert(alert)
    message = event.to_message()

    assert event.admin_only is True
    assert message["type"] == "alert_resolved"
    assert "message" not in message["data"]


def test_events_are_json_serializable():
    import json

    for event in (
        TelemetryUpdatedEvent.from_reading(_reading()),
        AlertCreatedEvent.from_alert(_alert()),
        AlertResolvedEvent.from_alert(_alert(is_resolved=True)),
    ):
        json.dumps(event.to_message())  # no debe fallar con uuid/datetime/enum


# --------------------------------------------------------------------------
# Publisher
# --------------------------------------------------------------------------


# Simula el ConnectionManager real, para probar el publisher sin sockets.
class FakeManager:
    def __init__(self, *, fails: bool = False) -> None:
        self.fails = fails
        self.calls: list[tuple[dict, bool]] = []

    async def broadcast(self, message: dict, *, admin_only: bool = False) -> None:
        if self.fails:
            raise RuntimeError("channel is down")
        self.calls.append((message, admin_only))


@pytest.mark.asyncio
async def test_null_publisher_drops_events_silently():
    # No debe fallar aunque nunca se conecte un canal real — es el default de
    # un servicio construido sin publisher.
    await NullEventPublisher().publish(TelemetryUpdatedEvent.from_reading(_reading()))


@pytest.mark.asyncio
async def test_websocket_publisher_forwards_the_message_and_admin_flag():
    fake_manager = FakeManager()
    publisher = WebSocketEventPublisher(fake_manager)

    await publisher.publish(AlertCreatedEvent.from_alert(_alert()))

    assert len(fake_manager.calls) == 1
    message, admin_only = fake_manager.calls[0]
    assert message["type"] == "alert_created"
    assert admin_only is True


@pytest.mark.asyncio
async def test_websocket_publisher_forwards_public_events_unrestricted():
    fake_manager = FakeManager()
    publisher = WebSocketEventPublisher(fake_manager)

    await publisher.publish(TelemetryUpdatedEvent.from_reading(_reading()))

    _, admin_only = fake_manager.calls[0]
    assert admin_only is False


@pytest.mark.asyncio
# Quien llama al publisher es un servicio a mitad de una transacción (una
# lectura recién guardada, una alerta recién resuelta). Que el canal falle
# nunca debe convertirse en un 500 ahí.
async def test_a_broadcast_failure_does_not_propagate_to_the_caller():
    publisher = WebSocketEventPublisher(FakeManager(fails=True))

    await publisher.publish(TelemetryUpdatedEvent.from_reading(_reading()))  # no debe fallar
