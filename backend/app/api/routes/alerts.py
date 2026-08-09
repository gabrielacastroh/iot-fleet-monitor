import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import require_admin
from app.core.exceptions import AlertNotFoundError, DeviceNotFoundError
from app.database.session import get_db
from app.models.alert import Alert
from app.schemas.alert import AlertCountQuery, AlertFilters, AlertQuery, AlertRead
from app.schemas.common import CountRead
from app.services.alert_service import alert_service

# Las alertas predictivas son solo para admin, por eso 
# cualquier endpoint nuevo queda protegido por defecto
router = APIRouter(
    prefix="/alerts",
    tags=["alerts"],
    dependencies=[Depends(require_admin)],
)


# Devuelve la lista de alertas de toda la flota, según los filtros recibidos.
@router.get("", response_model=list[AlertRead])
async def list_alerts(
    filters: Annotated[AlertQuery, Query()],
    db: AsyncSession = Depends(get_db),
) -> list[Alert]:
    return await alert_service.list_alerts(db, filters)


# Cuenta el total de alertas que matchean los filtros, sin límite de página.
@router.get("/count", response_model=CountRead)
async def count_alerts(
    filters: Annotated[AlertCountQuery, Query()],
    db: AsyncSession = Depends(get_db),
) -> CountRead:
    return CountRead(count=await alert_service.count_alerts(db, filters))


# Devuelve las alertas de un dispositivo puntual.
@router.get("/{device_id}", response_model=list[AlertRead])
async def list_device_alerts(
    device_id: uuid.UUID,
    filters: Annotated[AlertFilters, Query()],
    db: AsyncSession = Depends(get_db),
) -> list[Alert]:
    try:
        return await alert_service.list_device_alerts(db, device_id, filters)
    except DeviceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


# Marca una alerta como resuelta.
@router.patch("/{alert_id}/resolve", response_model=AlertRead)
async def resolve_alert(alert_id: uuid.UUID, db: AsyncSession = Depends(get_db)) -> Alert:
    try:
        return await alert_service.resolve_alert(db, alert_id)
    except AlertNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
