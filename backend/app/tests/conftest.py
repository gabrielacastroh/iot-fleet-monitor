import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.auth.security import create_access_token, hash_password
from app.database.base import Base
from app.database.session import get_db
from app.main import app
from app.models.user import User, UserRole

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


# Crea una base SQLite en memoria, nueva y vacía para cada test.
@pytest_asyncio.fixture
async def db_session_factory():
    engine = create_async_engine(TEST_DATABASE_URL)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield session_factory

    await engine.dispose()


# Sesión de DB suelta, para tests que tocan la base directo sin pasar por HTTP.
@pytest_asyncio.fixture
async def db_session(db_session_factory):
    async with db_session_factory() as session:
        yield session


# Cliente HTTP de prueba: pega contra la app sin levantar un server real, y
# hace que use la base en memoria en vez de la real.
@pytest_asyncio.fixture
async def async_client(db_session_factory):
    async def override_get_db():
        async with db_session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()


# Crea un usuario con el rol dado y devuelve el header Authorization listo para usar.
async def _auth_headers(db_session, *, role: UserRole, email: str) -> dict[str, str]:
    user = User(
        name=email.split("@")[0],
        email=email,
        hashed_password=hash_password("supersecret"),
        role=role,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    token = create_access_token(subject=str(user.id), role=user.role.value)
    return {"Authorization": f"Bearer {token}"}


# Header listo para pegarle a la API como admin.
@pytest_asyncio.fixture
async def admin_headers(db_session):
    return await _auth_headers(db_session, role=UserRole.ADMIN, email="admin@fleet.io")


# Header listo para pegarle a la API como usuario normal.
@pytest_asyncio.fixture
async def user_headers(db_session):
    return await _auth_headers(db_session, role=UserRole.USER, email="viewer@fleet.io")
