import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device import Device


# Lista todos los dispositivos, más nuevos primero.
async def list_all(db: AsyncSession) -> list[Device]:
    result = await db.execute(select(Device).order_by(Device.created_at.desc()))
    return list(result.scalars().all())


# Busca un dispositivo por id.
async def get_by_id(db: AsyncSession, device_id: uuid.UUID) -> Device | None:
    return await db.get(Device, device_id)


# Busca un dispositivo por su código de hardware. Se usa para chequear duplicados al crear/editar.
async def get_by_device_code(db: AsyncSession, device_code: str) -> Device | None:
    result = await db.execute(select(Device).where(Device.device_code == device_code))
    return result.scalar_one_or_none()


# Busca un dispositivo por matrícula. Se usa para chequear duplicados al crear/editar.
async def get_by_plate(db: AsyncSession, plate: str) -> Device | None:
    result = await db.execute(select(Device).where(Device.plate == plate))
    return result.scalar_one_or_none()


# Inserta un dispositivo nuevo.
async def create(db: AsyncSession, device: Device) -> Device:
    db.add(device)
    await db.commit()
    await db.refresh(device)
    return device


# Persiste cambios en un dispositivo existente.
async def save(db: AsyncSession, device: Device) -> Device:
    await db.commit()
    await db.refresh(device)
    return device


# Borra un dispositivo. Al ser en cascada, también se borran sus lecturas y alertas.
async def delete(db: AsyncSession, device: Device) -> None:
    await db.delete(device)
    await db.commit()
