import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import get_current_user
from app.core.exceptions import DeviceNotFoundError
from app.database.session import get_db
from app.models.telemetry import TelemetryReading
from app.schemas.common import CountRead
from app.schemas.telemetry import (
    DEFAULT_PAGE_SIZE,
    MAX_PAGE_SIZE,
    TelemetryFilters,
    TelemetryQuery,
    TelemetryReadingCreate,
    TelemetryReadingRead,
)
from app.services import telemetry_service

router = APIRouter(
    prefix="/telemetry",
    tags=["telemetry"],
    dependencies=[Depends(get_current_user)],
)


# Recibe una lectura de telemetría de un dispositivo.
@router.post("", response_model=TelemetryReadingRead, status_code=status.HTTP_201_CREATED)
async def record_reading(
    payload: TelemetryReadingCreate,
    db: AsyncSession = Depends(get_db),
) -> TelemetryReading:
    try:
        ingestion = await telemetry_service.record_reading(db, payload)
        return ingestion.reading
    except DeviceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


# Lista lecturas de telemetría según filtros.
@router.get("", response_model=list[TelemetryReadingRead])
async def list_readings(
    filters: Annotated[TelemetryQuery, Query()],
    db: AsyncSession = Depends(get_db),
) -> list[TelemetryReading]:
    return await telemetry_service.list_readings(db, filters)


# Cuenta el total de lecturas que matchean los filtros, sin límite de página.
@router.get("/count", response_model=CountRead)
async def count_readings(
    filters: Annotated[TelemetryFilters, Query()],
    db: AsyncSession = Depends(get_db),
) -> CountRead:
    return CountRead(count=await telemetry_service.count_readings(db, filters))


# Devuelve el estado actual de la flota: última lectura de cada dispositivo.
@router.get("/latest", response_model=list[TelemetryReadingRead])
async def list_latest_readings(
    db: AsyncSession = Depends(get_db),
) -> list[TelemetryReading]:
    return await telemetry_service.list_latest_readings(db)


# Devuelve el histórico de lecturas de un dispositivo, paginado y filtrable por fecha.
@router.get("/{device_id}/history", response_model=list[TelemetryReadingRead])
async def get_device_history(
    device_id: uuid.UUID,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    limit: int = Query(default=DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
    db: AsyncSession = Depends(get_db),
) -> list[TelemetryReading]:
    try:
        return await telemetry_service.get_device_history(
            db, device_id, limit=limit, start_date=start_date, end_date=end_date
        )
    except DeviceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
