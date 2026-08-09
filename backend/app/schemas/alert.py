import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.alert import AlertType

DEFAULT_PAGE_SIZE = 100
MAX_PAGE_SIZE = 1000

# Alert.message is a String(255); truncating silently would hide the reason an
# alert was raised, so the schema rejects anything longer up front.
MAX_MESSAGE_LENGTH = 255


# Clase base con los filtros comunes: por tipo de alerta y si está resuelta.
class AlertCriteria(BaseModel):
    alert_type: AlertType | None = None
    is_resolved: bool | None = None


# Clase para paginar: los mismos filtros más el tamaño de página.
class AlertFilters(AlertCriteria):
    limit: int = Field(default=DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE)


# Clase para listar las alertas de toda la flota, con filtro opcional por dispositivo.
class AlertQuery(AlertFilters):
    device_id: uuid.UUID | None = None


# Clase para el endpoint que cuenta alertas (mismos filtros, sin paginar).
class AlertCountQuery(AlertCriteria):
    device_id: uuid.UUID | None = None


# Clase para crear una alerta nueva.
class AlertCreate(BaseModel):
    device_id: uuid.UUID
    alert_type: AlertType
    message: str = Field(min_length=1, max_length=MAX_MESSAGE_LENGTH)


# Clase para devolver una alerta en las respuestas de la API.
class AlertRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    device_id: uuid.UUID
    alert_type: AlertType
    message: str
    is_resolved: bool
    created_at: datetime
