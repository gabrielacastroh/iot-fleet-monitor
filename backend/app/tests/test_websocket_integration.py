# Tests de punta a punta: una conexión WebSocket real contra el endpoint real
# /ws/telemetry, recibiendo eventos que un request HTTP real disparó.
#
# Acá se usa el TestClient síncrono de Starlette en vez del cliente async que
# usa el resto de la suite, porque el transporte ASGI de httpx no habla el
# protocolo WebSocket. El TestClient corre toda la app en un event loop de
# fondo mientras dura el bloque `with`, por eso la base se arma con una
# conexión síncrona a un archivo temporal (no :memory:) — así la conexión de
# setup y el engine async de la app, que viven en dos event loops distintos,
# siguen viendo los mismos datos.

import tempfile
from pathlib import Path

import pytest
from fastapi import WebSocketDisconnect
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.orm import Session

import app.websocket.router as ws_router
from app.auth.security import create_access_token, hash_password
from app.database.base import Base
from app.database.session import get_db
from app.main import app
from app.models.user import User, UserRole

READING = {
    "latitude": 4.65,
    "longitude": -74.05,
    "speed": 62.5,
    "fuel_level": 45.0,
    "temperature": 89.0,
}


# Levanta la app con un cliente que sí soporta WebSocket, contra una DB
# temporal en archivo, y devuelve un token de admin ya listo.
@pytest.fixture
def ws_client():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "ws_test.db"

        sync_engine = create_engine(f"sqlite:///{db_path}")
        Base.metadata.create_all(sync_engine)
        admin = User(
            name="ws-admin",
            email="ws-admin@fleet.io",
            hashed_password=hash_password("supersecret"),
            role=UserRole.ADMIN,
        )
        with Session(sync_engine) as session:
            session.add(admin)
            session.commit()
            session.refresh(admin)
        sync_engine.dispose()

        admin_token = create_access_token(subject=str(admin.id), role=admin.role.value)

        async_engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        session_factory = async_sessionmaker(async_engine, expire_on_commit=False)

        async def override_get_db():
            async with session_factory() as session:
                yield session

        app.dependency_overrides[get_db] = override_get_db

        # /ws/telemetry no toma la sesión por Depends (la soltaría recién al
        # cerrarse el socket), así que dependency_overrides no lo alcanza:
        # hay que apuntar su factory a la base temporal a mano.
        original_factory = ws_router.async_session_factory
        ws_router.async_session_factory = session_factory

        with TestClient(app) as client:
            yield client, admin_token

        ws_router.async_session_factory = original_factory
        app.dependency_overrides.clear()


# Crea un dispositivo de prueba vía la API.
def _create_device(client: TestClient, admin_token: str) -> dict:
    response = client.post(
        "/devices",
        json={"vehicle_name": "Truck 1", "device_code": "DEV-1", "plate": "ABC123"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201, response.text
    return response.json()


# Manda una lectura de telemetría de prueba vía la API.
def _post_reading(client: TestClient, admin_token: str, device_id: str, **overrides) -> dict:
    response = client.post(
        "/telemetry",
        json={"device_id": device_id, **READING, **overrides},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_connecting_without_a_token_is_refused(ws_client):
    client, _ = ws_client

    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/ws/telemetry"):
            pass


def test_connecting_with_a_garbage_token_is_refused(ws_client):
    client, _ = ws_client

    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/ws/telemetry?token=not-a-jwt"):
            pass


def test_a_stored_reading_is_broadcast_to_a_connected_client(ws_client):
    client, admin_token = ws_client
    device = _create_device(client, admin_token)

    with client.websocket_connect(f"/ws/telemetry?token={admin_token}") as ws:
        reading = _post_reading(client, admin_token, device["id"])
        message = ws.receive_json()

    assert message["type"] == "telemetry_updated"
    assert message["data"]["device_id"] == device["id"]
    assert message["data"]["reading_id"] == reading["id"]
    assert message["data"]["fuel_level"] == READING["fuel_level"]


def test_multiple_concurrent_clients_all_receive_the_same_broadcast(ws_client):
    client, admin_token = ws_client
    device = _create_device(client, admin_token)

    with client.websocket_connect(f"/ws/telemetry?token={admin_token}") as first:
        with client.websocket_connect(f"/ws/telemetry?token={admin_token}") as second:
            _post_reading(client, admin_token, device["id"])
            first_message = first.receive_json()
            second_message = second.receive_json()

    assert first_message["data"]["device_id"] == device["id"]
    assert second_message["data"]["device_id"] == device["id"]


def test_disconnecting_a_client_does_not_break_delivery_to_the_others(ws_client):
    client, admin_token = ws_client
    device = _create_device(client, admin_token)

    leaving = client.websocket_connect(f"/ws/telemetry?token={admin_token}")
    leaving.__enter__()
    leaving.__exit__(None, None, None)  # se desconecta antes de que se mande nada

    with client.websocket_connect(f"/ws/telemetry?token={admin_token}") as staying:
        _post_reading(client, admin_token, device["id"])
        message = staying.receive_json()

    assert message["data"]["device_id"] == device["id"]


# Dos lecturas con el combustible bajando, separadas por un instante real de
# reloj, alcanzan para que fuel_service pueda calcular una tasa de consumo —
# el tiempo real entre los dos requests HTTP hace de "historial reciente",
# igual que un dispositivo real reportando cada pocos segundos.
def test_a_critical_reading_also_broadcasts_alert_created_to_an_admin(ws_client):
    client, admin_token = ws_client
    device = _create_device(client, admin_token)

    with client.websocket_connect(f"/ws/telemetry?token={admin_token}") as ws:
        _post_reading(client, admin_token, device["id"], fuel_level=50.0)
        ws.receive_json()  # primer telemetry_updated

        _post_reading(client, admin_token, device["id"], fuel_level=49.0)
        second_update = ws.receive_json()
        alert_event = ws.receive_json()

    assert second_update["type"] == "telemetry_updated"
    assert alert_event["type"] == "alert_created"
    assert alert_event["data"]["device_id"] == device["id"]
    assert alert_event["data"]["alert_type"] == "low_fuel"
