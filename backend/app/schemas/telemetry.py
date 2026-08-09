import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

DEFAULT_PAGE_SIZE = 100
MAX_PAGE_SIZE = 1000


# Clase para los filtros del endpoint de conteo. 
class TelemetryFilters(BaseModel):
    device_id: uuid.UUID | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None

    @model_validator(mode="after")
    def check_date_range(self) -> "TelemetryFilters":
        if self.start_date and self.end_date and self.start_date > self.end_date:
            raise ValueError("start_date must be earlier than or equal to end_date")
        return self


# Clase para el endpoint de listado: mismos filtros más el tamaño de página.
class TelemetryQuery(TelemetryFilters):
    limit: int = Field(default=DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE)


# Clase para que un dispositivo mande una lectura nueva.
class TelemetryReadingCreate(BaseModel):
    device_id: uuid.UUID
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    speed: float = Field(ge=0)
    fuel_level: float = Field(ge=0, le=100)
    temperature: float


# Clase para devolver una lectura en las respuestas de la API.
class TelemetryReadingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    device_id: uuid.UUID
    latitude: float
    longitude: float
    speed: float
    fuel_level: float
    temperature: float
    recorded_at: datetime
