import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


# Clase para crear un dispositivo nuevo.
class DeviceCreate(BaseModel):
    vehicle_name: str = Field(min_length=1, max_length=255)
    device_code: str = Field(min_length=1, max_length=255)
    plate: str = Field(min_length=1, max_length=20)
    is_active: bool = True


# Clase para actualizar un dispositivo. Todos los campos son opcionales, así
# un PATCH solo cambia lo que el cliente mandó y no borra el resto.
class DeviceUpdate(BaseModel):
    vehicle_name: str | None = Field(default=None, min_length=1, max_length=255)
    device_code: str | None = Field(default=None, min_length=1, max_length=255)
    plate: str | None = Field(default=None, min_length=1, max_length=20)
    is_active: bool | None = None


# Clase para devolver un dispositivo en las respuestas de la API.
class DeviceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    vehicle_name: str
    device_code: str
    plate: str
    is_active: bool
    last_seen_at: datetime | None
    created_at: datetime
