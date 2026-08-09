import uuid
from datetime import datetime

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.telemetry import TelemetryReading


# Guarda una lectura nueva
async def create(db: AsyncSession, reading: TelemetryReading) -> TelemetryReading:
    db.add(reading)
    await db.commit()
    await db.refresh(reading)
    return reading


# Arma los filtros de la consulta. La usan list_filtered y count_filtered,
# así ambas siempre aplican exactamente los mismos criterios.
def _apply_filters(
    stmt: Select,
    *,
    device_id: uuid.UUID | None,
    start_date: datetime | None,
    end_date: datetime | None,
) -> Select:
    if device_id is not None:
        stmt = stmt.where(TelemetryReading.device_id == device_id)
    if start_date is not None:
        stmt = stmt.where(TelemetryReading.recorded_at >= start_date)
    if end_date is not None:
        stmt = stmt.where(TelemetryReading.recorded_at <= end_date)
    return stmt


# Lista lecturas según filtros, más nuevas primero.
async def list_filtered(
    db: AsyncSession,
    *,
    device_id: uuid.UUID | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    limit: int,
) -> list[TelemetryReading]:
    stmt = _apply_filters(
        select(TelemetryReading),
        device_id=device_id,
        start_date=start_date,
        end_date=end_date,
    )

    stmt = stmt.order_by(TelemetryReading.recorded_at.desc()).limit(limit)
    result = await db.execute(stmt)
    return list(result.scalars().all())


# Cuenta el total de lecturas que matchean, sin límite de página.
async def count_filtered(
    db: AsyncSession,
    *,
    device_id: uuid.UUID | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> int:
    stmt = _apply_filters(
        select(func.count()).select_from(TelemetryReading),
        device_id=device_id,
        start_date=start_date,
        end_date=end_date,
    )
    result = await db.execute(stmt)
    return result.scalar_one()


# Última lectura de cada dispositivo.
async def list_latest_per_device(db: AsyncSession) -> list[TelemetryReading]:
    ranked = select(
        TelemetryReading,
        func.row_number()
        .over(
            partition_by=TelemetryReading.device_id,
            order_by=TelemetryReading.recorded_at.desc(),
        )
        .label("rank"),
    ).subquery()

    latest = aliased(TelemetryReading, ranked)
    stmt = (
        select(latest)
        .where(ranked.c.rank == 1)
        .order_by(ranked.c.recorded_at.desc())
    )

    result = await db.execute(stmt)
    return list(result.scalars().all())
