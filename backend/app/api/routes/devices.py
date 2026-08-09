import uuid

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import get_current_user, require_admin
from app.core.exceptions import DeviceAlreadyExistsError, DeviceNotFoundError
from app.database.session import get_db
from app.models.device import Device
from app.models.user import User, UserRole
from app.schemas.device import DeviceCreate, DeviceRead, DeviceUpdate
from app.services import device_service

# Leer la flota es para cualquier usuario autenticado; escribir es solo admin,
# se valida ruta por ruta con require_admin.
router = APIRouter(
    prefix="/devices",
    tags=["devices"],
    dependencies=[Depends(get_current_user)],
)


# Arma la respuesta 404 cuando no existe el dispositivo.
def _not_found(exc: DeviceNotFoundError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


# Arma la respuesta 409 cuando ya existe un dispositivo con ese dato.
def _conflict(exc: DeviceAlreadyExistsError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={"field": exc.field, "message": str(exc)},
    )


def _visible_to(device: Device, user: User) -> DeviceRead:
    """El device_code identifica hardware físico, solo admin lo ve completo.

    Los dos endpoints de lectura pasan por acá para que ninguno se olvide de enmascararlo.
    """
    device_read = DeviceRead.model_validate(device)
    if user.role == UserRole.ADMIN:
        return device_read
    return device_read.model_copy(
        update={"device_code": device_service.mask_device_code(device_read.device_code)}
    )


# Lista todos los dispositivos de la flota.
@router.get("", response_model=list[DeviceRead])
async def list_devices(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[DeviceRead]:
    devices = await device_service.list_devices(db)
    return [_visible_to(device, current_user) for device in devices]


# Devuelve un dispositivo puntual.
@router.get("/{device_id}", response_model=DeviceRead)
async def get_device(
    device_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DeviceRead:
    try:
        device = await device_service.get_device(db, device_id)
    except DeviceNotFoundError as exc:
        raise _not_found(exc) from exc
    return _visible_to(device, current_user)


# Crea un dispositivo nuevo.
@router.post(
    "",
    response_model=DeviceRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin)],
)
async def create_device(payload: DeviceCreate, db: AsyncSession = Depends(get_db)) -> Device:
    try:
        return await device_service.create_device(db, payload)
    except DeviceAlreadyExistsError as exc:
        raise _conflict(exc) from exc


# Actualiza datos de un dispositivo existente.
@router.patch(
    "/{device_id}",
    response_model=DeviceRead,
    dependencies=[Depends(require_admin)],
)
async def update_device(
    device_id: uuid.UUID,
    payload: DeviceUpdate,
    db: AsyncSession = Depends(get_db),
) -> Device:
    try:
        return await device_service.update_device(db, device_id, payload)
    except DeviceNotFoundError as exc:
        raise _not_found(exc) from exc
    except DeviceAlreadyExistsError as exc:
        raise _conflict(exc) from exc


# Elimina un dispositivo.
@router.delete(
    "/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_admin)],
)
async def delete_device(device_id: uuid.UUID, db: AsyncSession = Depends(get_db)) -> Response:
    try:
        await device_service.delete_device(db, device_id)
    except DeviceNotFoundError as exc:
        raise _not_found(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
