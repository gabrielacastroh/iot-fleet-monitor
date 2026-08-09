import uuid

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert, AlertType


# Busca una alerta por id.
async def get_by_id(db: AsyncSession, alert_id: uuid.UUID) -> Alert | None:
    return await db.get(Alert, alert_id)


# Busca si ya hay una alerta abierta de este tipo para el dispositivo, para
# no duplicar: un camión con combustible bajo por una hora debe generar UNA
# alerta, no una por cada lectura de telemetría que llega.
async def get_active(
    db: AsyncSession, *, device_id: uuid.UUID, alert_type: AlertType
) -> Alert | None:
    stmt = (
        select(Alert)
        .where(
            Alert.device_id == device_id,
            Alert.alert_type == alert_type,
            Alert.is_resolved.is_(False),
        )
        .order_by(Alert.created_at.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    return result.scalars().first()


# Arma los filtros de la consulta. La usan list_filtered y count_filtered,
# así ambas siempre aplican exactamente los mismos criterios.
def _apply_filters(
    stmt: Select,
    *,
    device_id: uuid.UUID | None,
    alert_type: AlertType | None,
    is_resolved: bool | None,
) -> Select:
    if device_id is not None:
        stmt = stmt.where(Alert.device_id == device_id)
    if alert_type is not None:
        stmt = stmt.where(Alert.alert_type == alert_type)
    if is_resolved is not None:
        stmt = stmt.where(Alert.is_resolved.is_(is_resolved))
    return stmt


# Lista alertas, más nuevas primero. Un filtro en None significa "no filtrar por esto".
async def list_filtered(
    db: AsyncSession,
    *,
    device_id: uuid.UUID | None = None,
    alert_type: AlertType | None = None,
    is_resolved: bool | None = None,
    limit: int,
) -> list[Alert]:
    stmt = _apply_filters(
        select(Alert), device_id=device_id, alert_type=alert_type, is_resolved=is_resolved
    )

    stmt = stmt.order_by(Alert.created_at.desc()).limit(limit)
    result = await db.execute(stmt)
    return list(result.scalars().all())


# Cuenta el total de alertas que matchean, sin límite de página.
async def count_filtered(
    db: AsyncSession,
    *,
    device_id: uuid.UUID | None = None,
    alert_type: AlertType | None = None,
    is_resolved: bool | None = None,
) -> int:
    stmt = _apply_filters(
        select(func.count()).select_from(Alert),
        device_id=device_id,
        alert_type=alert_type,
        is_resolved=is_resolved,
    )
    result = await db.execute(stmt)
    return result.scalar_one()


# Inserta una alerta nueva.
async def create(db: AsyncSession, alert: Alert) -> Alert:
    db.add(alert)
    await db.commit()
    await db.refresh(alert)
    return alert


# Persiste cambios en una alerta existente.
async def save(db: AsyncSession, alert: Alert) -> Alert:
    await db.commit()
    await db.refresh(alert)
    return alert
