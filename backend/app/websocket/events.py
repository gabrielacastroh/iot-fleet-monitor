# Eventos que se mandan por el canal de tiempo real. Son solo datos: no
# saben nada de FastAPI, ni del ConnectionManager, ni de cómo viaja el dato
# por el canal. Un servicio arma uno de estos y se lo pasa a un publisher;
# cómo llega hasta el cliente (WebSocket hoy, podría ser otra cosa mañana) no
# es asunto de este módulo. to_message() convierte el evento a JSON.

import uuid
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Any, ClassVar

from app.models.alert import Alert, AlertType
from app.models.telemetry import TelemetryReading


class EventType(str, Enum):
    TELEMETRY_UPDATED = "telemetry_updated"
    ALERT_CREATED = "alert_created"
    ALERT_RESOLVED = "alert_resolved"


# Se acaba de guardar una lectura. Manda los datos de la lectura para que el
# dashboard se actualice al instante, sin tener que pedir GET /telemetry de nuevo.
@dataclass(frozen=True, slots=True)
class TelemetryUpdatedEvent:
    type: ClassVar[EventType] = EventType.TELEMETRY_UPDATED
    # Es información que cualquier usuario autenticado ya puede leer por
    # GET /telemetry, así que este canal no restringe quién la recibe.
    admin_only: ClassVar[bool] = False

    device_id: uuid.UUID
    reading_id: uuid.UUID
    latitude: float
    longitude: float
    speed: float
    fuel_level: float
    temperature: float
    recorded_at: datetime

    @classmethod
    def from_reading(cls, reading: TelemetryReading) -> "TelemetryUpdatedEvent":
        return cls(
            device_id=reading.device_id,
            reading_id=reading.id,
            latitude=reading.latitude,
            longitude=reading.longitude,
            speed=reading.speed,
            fuel_level=reading.fuel_level,
            temperature=reading.temperature,
            recorded_at=reading.recorded_at,
        )

    def to_message(self) -> dict[str, Any]:
        return {
            "type": self.type.value,
            "data": {
                "device_id": str(self.device_id),
                "reading_id": str(self.reading_id),
                "latitude": self.latitude,
                "longitude": self.longitude,
                "speed": self.speed,
                "fuel_level": self.fuel_level,
                "temperature": self.temperature,
                "recorded_at": self.recorded_at.isoformat(),
            },
        }


# Se abrió una alerta nueva (el servicio solo dispara esto en la apertura
# real, no en cada lectura que solo reconfirma una ya abierta).
@dataclass(frozen=True, slots=True)
class AlertCreatedEvent:
    type: ClassVar[EventType] = EventType.ALERT_CREATED
    # Igual que GET /alerts exige admin, este canal tampoco debe filtrar
    # contenido de alertas a una conexión que no es admin.
    admin_only: ClassVar[bool] = True

    id: uuid.UUID
    device_id: uuid.UUID
    alert_type: AlertType
    message: str
    created_at: datetime

    @classmethod
    def from_alert(cls, alert: Alert) -> "AlertCreatedEvent":
        return cls(
            id=alert.id,
            device_id=alert.device_id,
            alert_type=alert.alert_type,
            message=alert.message,
            created_at=alert.created_at,
        )

    def to_message(self) -> dict[str, Any]:
        return {
            "type": self.type.value,
            "data": {
                "id": str(self.id),
                "device_id": str(self.device_id),
                "alert_type": self.alert_type.value,
                "message": self.message,
                "created_at": self.created_at.isoformat(),
            },
        }


# Se cerró una alerta, a mano o porque la predicción se recuperó sola. Sin
# campo message: el frontend solo necesita el id para sacarla de la lista de abiertas.
@dataclass(frozen=True, slots=True)
class AlertResolvedEvent:
    type: ClassVar[EventType] = EventType.ALERT_RESOLVED
    admin_only: ClassVar[bool] = True

    id: uuid.UUID
    device_id: uuid.UUID
    alert_type: AlertType

    @classmethod
    def from_alert(cls, alert: Alert) -> "AlertResolvedEvent":
        return cls(id=alert.id, device_id=alert.device_id, alert_type=alert.alert_type)

    def to_message(self) -> dict[str, Any]:
        return {
            "type": self.type.value,
            "data": {
                "id": str(self.id),
                "device_id": str(self.device_id),
                "alert_type": self.alert_type.value,
            },
        }


DomainEvent = TelemetryUpdatedEvent | AlertCreatedEvent | AlertResolvedEvent
