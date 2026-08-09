# Tests del ConnectionManager solo: ciclo de vida de la conexión y entrega
# según el rol, usando WebSockets falsos, sin socket real ni base de datos.

import pytest

from app.websocket.manager import ConnectionManager


# Reemplaza a fastapi.WebSocket: guarda lo que le llegó y se le puede pedir
# que falle, para simular una conexión caída.
class FakeWebSocket:
    def __init__(self, *, fails: bool = False) -> None:
        self.fails = fails
        self.accepted = False
        self.received: list[dict] = []

    async def accept(self) -> None:
        self.accepted = True

    async def send_json(self, message: dict) -> None:
        if self.fails:
            raise RuntimeError("connection reset")
        self.received.append(message)


@pytest.mark.asyncio
async def test_connect_accepts_the_handshake():
    manager = ConnectionManager()
    socket = FakeWebSocket()

    await manager.connect(socket)

    assert socket.accepted is True
    assert manager.connection_count == 1


@pytest.mark.asyncio
async def test_disconnect_removes_the_client():
    manager = ConnectionManager()
    socket = FakeWebSocket()
    await manager.connect(socket)

    manager.disconnect(socket)

    assert manager.connection_count == 0


@pytest.mark.asyncio
async def test_disconnecting_an_unknown_socket_is_a_no_op():
    # Desconectar dos veces (ej: el except y después una limpieza posterior)
    # no debe fallar.
    manager = ConnectionManager()

    manager.disconnect(FakeWebSocket())

    assert manager.connection_count == 0


@pytest.mark.asyncio
async def test_broadcast_reaches_every_connected_client():
    manager = ConnectionManager()
    first, second = FakeWebSocket(), FakeWebSocket()
    await manager.connect(first)
    await manager.connect(second)

    await manager.broadcast({"type": "telemetry_updated"})

    assert first.received == [{"type": "telemetry_updated"}]
    assert second.received == [{"type": "telemetry_updated"}]


@pytest.mark.asyncio
# La regla que GET /alerts aplica con require_admin también debe valer acá:
# un usuario normal nunca debe recibir contenido de alertas.
async def test_admin_only_broadcast_skips_non_admin_clients():
    manager = ConnectionManager()
    viewer, admin = FakeWebSocket(), FakeWebSocket()
    await manager.connect(viewer, is_admin=False)
    await manager.connect(admin, is_admin=True)

    await manager.broadcast({"type": "alert_created"}, admin_only=True)

    assert viewer.received == []
    assert admin.received == [{"type": "alert_created"}]


@pytest.mark.asyncio
async def test_public_broadcast_reaches_admins_too():
    manager = ConnectionManager()
    admin = FakeWebSocket()
    await manager.connect(admin, is_admin=True)

    await manager.broadcast({"type": "telemetry_updated"}, admin_only=False)

    assert admin.received == [{"type": "telemetry_updated"}]


@pytest.mark.asyncio
# Un cliente que desapareció sin cerrar bien la conexión (se cortó la señal,
# se cerró la pestaña) no debe arruinar la entrega a los que siguen conectados.
async def test_a_dead_connection_is_pruned_without_breaking_the_others():
    manager = ConnectionManager()
    dead, alive = FakeWebSocket(fails=True), FakeWebSocket()
    await manager.connect(dead)
    await manager.connect(alive)

    await manager.broadcast({"type": "telemetry_updated"})

    assert alive.received == [{"type": "telemetry_updated"}]
    assert manager.connection_count == 1


@pytest.mark.asyncio
async def test_a_pruned_connection_does_not_receive_later_broadcasts():
    manager = ConnectionManager()
    dead, alive = FakeWebSocket(fails=True), FakeWebSocket()
    await manager.connect(dead)
    await manager.connect(alive)
    await manager.broadcast({"type": "first"})

    dead.fails = False  # aunque "se recupere", ya no está siendo trackeado
    await manager.broadcast({"type": "second"})

    assert dead.received == []
    assert alive.received == [{"type": "first"}, {"type": "second"}]


@pytest.mark.asyncio
async def test_broadcast_with_no_clients_does_nothing():
    manager = ConnectionManager()

    await manager.broadcast({"type": "telemetry_updated"})  # must not raise

    assert manager.connection_count == 0
