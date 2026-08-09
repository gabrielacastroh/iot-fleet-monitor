from app.auth.security import verify_password
from app.models.user import UserRole
from app.repositories import user_repository
from app.seed import seed


# El admin sembrado tiene que quedar con rol ADMIN: es lo único que habilita
# el alta de dispositivos y el feed de alertas.
async def test_seed_creates_admin_and_regular_user(monkeypatch, db_session_factory, db_session):
    monkeypatch.setenv("SEED_ADMIN_EMAIL", "admin@fleet.io")
    monkeypatch.setenv("SEED_ADMIN_PASSWORD", "admin12345")
    monkeypatch.setenv("SEED_USER_EMAIL", "user@fleet.io")
    monkeypatch.setenv("SEED_USER_PASSWORD", "user12345")

    await seed(db_session_factory)

    admin = await user_repository.get_by_email(db_session, "admin@fleet.io")
    assert admin is not None
    assert admin.role == UserRole.ADMIN
    assert verify_password("admin12345", admin.hashed_password)

    user = await user_repository.get_by_email(db_session, "user@fleet.io")
    assert user is not None
    assert user.role == UserRole.USER


# Corre en cada arranque del backend, así que reejecutarlo no puede duplicar
# cuentas ni fallar por el email único.
async def test_seed_is_idempotent_and_reapplies_the_password(
    monkeypatch, db_session_factory, db_session
):
    monkeypatch.setenv("SEED_ADMIN_EMAIL", "admin@fleet.io")
    monkeypatch.setenv("SEED_ADMIN_PASSWORD", "admin12345")

    await seed(db_session_factory)
    first = await user_repository.get_by_email(db_session, "admin@fleet.io")
    assert first is not None
    first_id = first.id

    monkeypatch.setenv("SEED_ADMIN_PASSWORD", "rotated12345")
    await seed(db_session_factory)

    # El seed escribe desde su propia sesión; sin esto se leería la copia que
    # esta sesión ya tiene cacheada en su identity map.
    db_session.expunge_all()
    admin = await user_repository.get_by_email(db_session, "admin@fleet.io")
    assert admin is not None
    assert admin.id == first_id
    assert verify_password("rotated12345", admin.hashed_password)


# El email se normaliza igual que en el registro, para que Admin@Fleet.IO y
# admin@fleet.io no terminen siendo dos cuentas distintas.
async def test_seed_normalizes_the_email(monkeypatch, db_session_factory, db_session):
    monkeypatch.setenv("SEED_ADMIN_EMAIL", "  Admin@Fleet.IO  ")
    monkeypatch.setenv("SEED_ADMIN_PASSWORD", "admin12345")

    await seed(db_session_factory)

    assert await user_repository.get_by_email(db_session, "admin@fleet.io") is not None
