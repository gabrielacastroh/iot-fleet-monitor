"""Crea las cuentas de demo (admin + usuario) al arrancar el backend.

Existe porque `POST /auth/register` siempre crea rol USER: sin esto, para
probar los flujos de admin (alta de dispositivos, feed de alertas) o para
correr el simulador hay que promover una cuenta a mano con SQL.

Se ejecuta con `python -m app.seed`, después de `alembic upgrade head`.
Es idempotente: reaplica en cada arranque nombre, rol, estado y contraseña
tomados del entorno, así el `.env` es la única fuente de verdad de las
credenciales de demo.
"""

import asyncio
import logging
import os

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.auth.security import hash_password
from app.database.session import async_session_factory
from app.models.user import User, UserRole
from app.repositories import user_repository
from app.services.auth_service import normalize_email

logging.basicConfig(level=logging.INFO, format="%(levelname)-7s %(message)s")
logger = logging.getLogger("app.seed")


# Cuentas de evaluación. Los defaults coinciden con .env.example: son
# credenciales de demo, no secretos — el .env real las sobreescribe.
def _demo_users() -> list[tuple[str, str, str, UserRole]]:
    return [
        (
            "Fleet Admin",
            os.environ.get("SEED_ADMIN_EMAIL", "admin@fleet.io"),
            os.environ.get("SEED_ADMIN_PASSWORD", "admin12345"),
            UserRole.ADMIN,
        ),
        (
            "Fleet Viewer",
            os.environ.get("SEED_USER_EMAIL", "user@fleet.io"),
            os.environ.get("SEED_USER_PASSWORD", "user12345"),
            UserRole.USER,
        ),
    ]


async def seed(session_factory: async_sessionmaker[AsyncSession] = async_session_factory) -> None:
    async with session_factory() as db:
        for name, raw_email, password, role in _demo_users():
            email = normalize_email(raw_email)
            user = await user_repository.get_by_email(db, email)

            if user is None:
                await user_repository.create(
                    db,
                    User(
                        name=name,
                        email=email,
                        hashed_password=hash_password(password),
                        role=role,
                    ),
                )
                logger.info("Cuenta de demo creada: %s (%s)", email, role.value)
                continue

            # ponytail: se pisa siempre en vez de comparar campo por campo.
            # Son dos cuentas fijas de demo; que el .env mande es más útil
            # que preservar cambios hechos a mano sobre ellas.
            user.name = name
            user.hashed_password = hash_password(password)
            user.role = role
            user.is_active = True
            await db.commit()
            logger.info("Cuenta de demo actualizada: %s (%s)", email, role.value)


if __name__ == "__main__":
    asyncio.run(seed())
