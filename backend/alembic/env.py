import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

from app.core.config import get_settings
from app.database.base import Base
# Se importan todos los modelos para que Alembic los detecte al generar migraciones automáticas.
from app.models import alert, device, telemetry, user

# Objeto de configuración de Alembic, da acceso a los valores del archivo .ini.
config = context.config

# Configura el logging según lo indicado en el archivo .ini.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# La URL de conexión se toma de la configuración de la app (.env / DATABASE_URL)
# para no repetirla también en alembic.ini.
config.set_main_option("sqlalchemy.url", get_settings().database_url)

# Metadata con la definición de todas las tablas, usada para comparar y generar migraciones.
target_metadata = Base.metadata

def run_migrations_offline() -> None:
    """Modo 'offline': genera el SQL de la migración sin conectarse a la base de datos.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Crea el engine async y corre las migraciones sobre una conexión real.
    """

    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Modo 'online': se conecta a la base de datos real y aplica la migración."""

    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
