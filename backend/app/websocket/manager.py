# Maneja las conexiones del canal de tiempo real: conectar, desconectar, y
# mandar un mensaje al grupo correcto de clientes. No sabe qué significa
# "telemetry_updated" ni qué es una alerta — un mensaje es solo un dict, y
# admin_only es solo un filtro sobre quién se conectó como admin.

import logging
from dataclasses import dataclass

from fastapi import WebSocket

logger = logging.getLogger(__name__)


# Una conexión aceptada, más lo único que hace falta saber de ella para
# rutear mensajes: si puede ver eventos admin-only.
@dataclass(frozen=True, slots=True)
class _Client:
    websocket: WebSocket
    is_admin: bool


class ConnectionManager:
    def __init__(self) -> None:
        self._clients: list[_Client] = []

    async def connect(self, websocket: WebSocket, *, is_admin: bool = False) -> None:
        await websocket.accept()
        self._clients.append(_Client(websocket, is_admin))

    def disconnect(self, websocket: WebSocket) -> None:
        self._clients = [client for client in self._clients if client.websocket is not websocket]

    @property
    def connection_count(self) -> int:
        return len(self._clients)

    # Manda el mensaje a todos los clientes (o solo a los admin, si
    # admin_only). Si una conexión se cayó sin avisar, el envío falla acá y
    # se la saca de la lista en el momento, en vez de seguir fallando en cada
    # broadcast siguiente.
    async def broadcast(self, message: dict, *, admin_only: bool = False) -> None:
        targets = [client for client in self._clients if client.is_admin or not admin_only]

        dead: list[WebSocket] = []
        for client in targets:
            try:
                await client.websocket.send_json(message)
            except Exception:
                dead.append(client.websocket)

        for websocket in dead:
            logger.info("Pruning dead WebSocket connection")
            self.disconnect(websocket)


manager = ConnectionManager()
