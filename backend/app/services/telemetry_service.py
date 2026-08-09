import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert
from app.models.device import Device
from app.models.telemetry import TelemetryReading
from app.repositories import telemetry_repository
from app.schemas.telemetry import TelemetryFilters, TelemetryQuery, TelemetryReadingCreate
from app.services import device_service
from app.services.alert_service import alert_service
from app.services.fuel_service import FuelPrediction, FuelService
from app.websocket.events import TelemetryUpdatedEvent
from app.websocket.publisher import EventPublisher, default_event_publisher

logger = logging.getLogger(__name__)

# Cuántas lecturas recientes mira la predicción de combustible: suficientes
# para promediar un sensor ruidoso, pocas para que una carga de hace horas no domine.
FUEL_HISTORY_SAMPLES = 20

_fuel_service = FuelService()

_event_publisher: EventPublisher = default_event_publisher


@dataclass(frozen=True, slots=True)
class ReadingIngestion:
    reading: TelemetryReading
    fuel: FuelPrediction
    alert: Alert | None


# Procesa una lectura nueva: valida el dispositivo, la guarda y actualiza su
# last_seen_at, todo en una sola transacción.
async def record_reading(db: AsyncSession, payload: TelemetryReadingCreate) -> ReadingIngestion:
    device = await device_service.get_device(db, payload.device_id)

    # Se toma la hora acá en vez de dejarla al default de la columna, para que
    # la lectura y el last_seen_at del dispositivo tengan exactamente el mismo instante.
    recorded_at = datetime.now(timezone.utc)

    reading = TelemetryReading(
        device_id=device.id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        speed=payload.speed,
        fuel_level=payload.fuel_level,
        temperature=payload.temperature,
        recorded_at=recorded_at,
    )
    _mark_device_as_seen(device, recorded_at)

    saved = await telemetry_repository.create(db, reading)

    return await _dispatch_reading_events(db, device, saved)


# Lista lecturas según filtros, con paginación.
async def list_readings(db: AsyncSession, filters: TelemetryQuery) -> list[TelemetryReading]:
    return await telemetry_repository.list_filtered(
        db,
        device_id=filters.device_id,
        start_date=filters.start_date,
        end_date=filters.end_date,
        limit=filters.limit,
    )


# Cuenta el total de lecturas que matchean los filtros, sin límite de página.
async def count_readings(db: AsyncSession, filters: TelemetryFilters) -> int:
    return await telemetry_repository.count_filtered(
        db,
        device_id=filters.device_id,
        start_date=filters.start_date,
        end_date=filters.end_date,
    )


# Última lectura de cada dispositivo, para el estado actual de la flota. Un
# dispositivo que nunca reportó simplemente no aparece (distinto de "reportó hace rato").
async def list_latest_readings(db: AsyncSession) -> list[TelemetryReading]:
    return await telemetry_repository.list_latest_per_device(db)


# Historial de un vehículo. Valida primero que el dispositivo exista, para
# devolver 404 en vez de una lista vacía que se confundiría con "sin lecturas".
async def get_device_history(
    db: AsyncSession,
    device_id: uuid.UUID,
    *,
    limit: int,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> list[TelemetryReading]:
    await device_service.get_device(db, device_id)

    return await telemetry_repository.list_filtered(
        db,
        device_id=device_id,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )


def _mark_device_as_seen(device: Device, seen_at: datetime) -> None:
    device.last_seen_at = seen_at


# record_reading ya guardó la lectura en la base. Esta función se ocupa de
# todo lo que pasa DESPUÉS de guardarla, en este orden:
#
#   1. Calcular la predicción de combustible con el historial reciente.
#   2. Avisar por WebSocket que hay una lectura nueva (para que el dashboard
#      se actualice en vivo).
#   3. Recién ahí, revisar si esa predicción abre, mantiene o cierra una
#      alerta de combustible bajo.
#
# Todo esto corre después de guardar la lectura
async def _dispatch_reading_events(
    db: AsyncSession,
    device: Device,
    reading: TelemetryReading,
) -> ReadingIngestion:
    prediction = await _predict_fuel(db, device)
    await _event_publisher.publish(TelemetryUpdatedEvent.from_reading(reading))
    alert = await _sync_alerts(db, device, prediction)

    logger.debug(
        "Reading ingested",
        extra={
            "device_id": str(device.id),
            "reading_id": str(reading.id),
            "fuel_status": prediction.status.value,
            "hours_remaining": prediction.hours_remaining,
            "should_alert": prediction.should_alert,
        },
    )
    return ReadingIngestion(reading=reading, fuel=prediction, alert=alert)


# Le pasa la predicción al servicio de alertas, que decide si hay que abrir,
# mantener o cerrar una alerta. 
async def _sync_alerts(
    db: AsyncSession, device: Device, prediction: FuelPrediction
) -> Alert | None:
    try:
        return await alert_service.sync_fuel_alert(db, device.id, prediction)
    except Exception:
        await db.rollback()
        logger.exception("Alert sync failed", extra={"device_id": str(device.id)})
        return None


# Lee el historial reciente del dispositivo y se lo pasa al fuel_service para calcular.
async def _predict_fuel(db: AsyncSession, device: Device) -> FuelPrediction:
    history = await telemetry_repository.list_filtered(
        db,
        device_id=device.id,
        limit=FUEL_HISTORY_SAMPLES,
    )
    return _fuel_service.evaluate(history)
