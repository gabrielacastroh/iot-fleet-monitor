import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import DeviceAlreadyExistsError, DeviceNotFoundError
from app.models.device import Device
from app.repositories import device_repository
from app.schemas.device import DeviceCreate, DeviceUpdate

logger = logging.getLogger(__name__)


# Normaliza el código del dispositivo (sin espacios, en mayúsculas) para que
# no se registren duplicados por diferencias de formato.
def normalize_device_code(device_code: str) -> str:
    return device_code.strip().upper()


# Cuánto del código queda visible al enmascarar: el prefijo y el final.
VISIBLE_PREFIX = 3
VISIBLE_SUFFIX = 4

# Por debajo de este largo no queda nada en el medio para ocultar.
_MIN_MASKABLE_LENGTH = VISIBLE_PREFIX + VISIBLE_SUFFIX + 2


# Oculta la parte del medio del código de un dispositivo para usuarios no
# admin. "DEV-1234-XC54" se muestra como "DEV-****-XC54": alcanza para
# distinguir dos vehículos, pero no para identificar el hardware real.
def mask_device_code(device_code: str) -> str:
    prefix = device_code[:VISIBLE_PREFIX]
    if len(device_code) < _MIN_MASKABLE_LENGTH:
        return f"{prefix}-****"
    return f"{prefix}-****-{device_code[-VISIBLE_SUFFIX:]}"


# Normaliza la matrícula (sin espacios, en mayúsculas).
def normalize_plate(plate: str) -> str:
    return plate.strip().upper()


# Chequea que el código no esté usado por otro dispositivo antes de guardar.
async def _ensure_device_code_is_free(
    db: AsyncSession, device_code: str, *, exclude_id: uuid.UUID | None = None
) -> None:
    existing = await device_repository.get_by_device_code(db, device_code)
    if existing is not None and existing.id != exclude_id:
        raise DeviceAlreadyExistsError(
            f"Device code '{device_code}' is already registered", field="device_code"
        )


# Chequea que la matrícula no esté usada por otro dispositivo antes de guardar.
async def _ensure_plate_is_free(
    db: AsyncSession, plate: str, *, exclude_id: uuid.UUID | None = None
) -> None:
    existing = await device_repository.get_by_plate(db, plate)
    if existing is not None and existing.id != exclude_id:
        raise DeviceAlreadyExistsError(f"Plate '{plate}' is already registered", field="plate")


# Lista todos los dispositivos.
async def list_devices(db: AsyncSession) -> list[Device]:
    return await device_repository.list_all(db)


# Busca un dispositivo por id, o lanza error si no existe. Otros módulos
# (como telemetría) reusan esta función para saber si un device_id es válido.
async def get_device(db: AsyncSession, device_id: uuid.UUID) -> Device:
    device = await device_repository.get_by_id(db, device_id)
    if device is None:
        raise DeviceNotFoundError(f"Device '{device_id}' not found")
    return device


# Crea un dispositivo nuevo, validando que código y matrícula no estén repetidos.
async def create_device(db: AsyncSession, payload: DeviceCreate) -> Device:
    device_code = normalize_device_code(payload.device_code)
    plate = normalize_plate(payload.plate)

    await _ensure_device_code_is_free(db, device_code)
    await _ensure_plate_is_free(db, plate)

    device = Device(
        vehicle_name=payload.vehicle_name.strip(),
        device_code=device_code,
        plate=plate,
        is_active=payload.is_active,
    )
    created = await device_repository.create(db, device)
    logger.info("Device created", extra={"device_id": str(created.id), "device_code": device_code})
    return created


# Actualiza solo los campos que el cliente mandó en el PATCH.
async def update_device(db: AsyncSession, device_id: uuid.UUID, payload: DeviceUpdate) -> Device:
    device = await get_device(db, device_id)
    changes = payload.model_dump(exclude_unset=True, exclude_none=True)

    if "vehicle_name" in changes:
        device.vehicle_name = changes["vehicle_name"].strip()

    if "device_code" in changes:
        device_code = normalize_device_code(changes["device_code"])
        await _ensure_device_code_is_free(db, device_code, exclude_id=device.id)
        device.device_code = device_code

    if "plate" in changes:
        plate = normalize_plate(changes["plate"])
        await _ensure_plate_is_free(db, plate, exclude_id=device.id)
        device.plate = plate

    if "is_active" in changes:
        device.is_active = changes["is_active"]

    updated = await device_repository.save(db, device)
    logger.info("Device updated", extra={"device_id": str(device_id), "fields": sorted(changes)})
    return updated


# Borra un dispositivo (y en cascada, sus lecturas y alertas).
async def delete_device(db: AsyncSession, device_id: uuid.UUID) -> None:
    device = await get_device(db, device_id)
    await device_repository.delete(db, device)
    logger.info("Device deleted", extra={"device_id": str(device_id)})
