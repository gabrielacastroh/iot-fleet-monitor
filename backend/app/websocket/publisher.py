# Puente entre un evento de dominio y cómo termina llegando al cliente.
# TelemetryService y AlertService dependen de EventPublisher, nunca de
# ConnectionManager directamente. Sumar otro canal el día de mañana es
# escribir una clase nueva acá, sin tocar ninguno de los dos servicios.

import logging
from typing import Protocol

from app.websocket.events import DomainEvent
from app.websocket.manager import ConnectionManager, manager

logger = logging.getLogger(__name__)


# El molde que tiene que cumplir cualquier forma de publicar eventos: un
# método publish(event). Los servicios dependen de esto, nunca de una clase concreta.
class EventPublisher(Protocol):
    async def publish(self, event: DomainEvent) -> None: ...


# Publisher por defecto cuando no hay canal conectado: publicar no hace nada.
# Permite construir y testear los servicios sin necesitar infraestructura de WebSocket.
class NullEventPublisher:
    async def publish(self, event: DomainEvent) -> None:
        return None


# Publica mandando el evento por un ConnectionManager real. Un fallo acá
# nunca debe llegar a quien llama: un cliente cuya lectura ya se guardó no
# puede ver un 500 solo porque se cerró una pestaña a mitad del envío.
class WebSocketEventPublisher:
    def __init__(self, connection_manager: ConnectionManager) -> None:
        self._manager = connection_manager

    async def publish(self, event: DomainEvent) -> None:
        try:
            await self._manager.broadcast(event.to_message(), admin_only=event.admin_only)
        except Exception:
            logger.exception("Failed to publish event", extra={"event_type": event.type.value})


# Instancia compartida, conectada al connection manager compartido.
default_event_publisher = WebSocketEventPublisher(manager)
