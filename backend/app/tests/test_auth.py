import pytest

from app.auth import security
from app.models.user import User, UserRole

EMAIL = "admin@fleet.io"
PASSWORD = "supersecret"


# Crea un usuario directo en la base (sin pasar por /auth/register), para armar el escenario del test.
async def _create_user(db_session, *, is_active: bool = True, role: UserRole = UserRole.ADMIN) -> User:
    user = User(
        name="Admin",
        email=EMAIL,
        hashed_password=security.hash_password(PASSWORD),
        role=role,
        is_active=is_active,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.mark.asyncio
async def test_register_creates_user_that_can_log_in(async_client):
    response = await async_client.post(
        "/auth/register",
        json={"name": "New User", "email": "New.User@Fleet.io", "password": "supersecret"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "new.user@fleet.io"
    # El registro nunca debe otorgar admin, mande lo que mande el cliente.
    assert body["role"] == "user"

    login_response = await async_client.post(
        "/auth/login", data={"username": "new.user@fleet.io", "password": "supersecret"}
    )
    assert login_response.status_code == 200


@pytest.mark.asyncio
async def test_register_rejects_duplicate_email(async_client, db_session):
    await _create_user(db_session)

    response = await async_client.post(
        "/auth/register",
        json={"name": "Impostor", "email": EMAIL, "password": "supersecret"},
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_register_rejects_short_password(async_client):
    response = await async_client.post(
        "/auth/register",
        json={"name": "New User", "email": "short@fleet.io", "password": "123"},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_login_success_and_me(async_client, db_session):
    await _create_user(db_session)

    response = await async_client.post("/auth/login", data={"username": EMAIL, "password": PASSWORD})
    assert response.status_code == 200
    token = response.json()["access_token"]

    me_response = await async_client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_response.status_code == 200
    assert me_response.json()["email"] == EMAIL
    assert me_response.json()["role"] == "admin"


@pytest.mark.asyncio
async def test_login_wrong_password(async_client, db_session):
    await _create_user(db_session)

    response = await async_client.post("/auth/login", data={"username": EMAIL, "password": "wrong"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_unknown_user(async_client):
    response = await async_client.post("/auth/login", data={"username": EMAIL, "password": PASSWORD})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_inactive_user(async_client, db_session):
    await _create_user(db_session, is_active=False)

    response = await async_client.post("/auth/login", data={"username": EMAIL, "password": PASSWORD})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_rejects_expired_token(async_client, db_session):
    user = await _create_user(db_session)

    original_expiry = security.settings.access_token_expire_minutes
    security.settings.access_token_expire_minutes = -1
    try:
        expired_token = security.create_access_token(subject=str(user.id), role=user.role.value)
    finally:
        security.settings.access_token_expire_minutes = original_expiry

    response = await async_client.get("/auth/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_rejects_invalid_signature(async_client, db_session):
    user = await _create_user(db_session)
    token = security.create_access_token(subject=str(user.id), role=user.role.value)

    # Se cambia el primer carácter de la firma, no el último: el último
    # carácter de una firma de 32 bytes en base64url tiene bits de relleno
    # que el decoder ignora, así que a veces cambiarlo no cambia los bytes
    # reales y la firma "tamperada" termina siendo idéntica a la original
    # (test flaky). El primer carácter siempre representa bits completos, así
    # que tamperarlo garantiza una firma distinta en cada corrida.
    header_b64, payload_b64, signature_b64 = token.split(".")
    tampered_signature = ("A" if signature_b64[0] != "A" else "B") + signature_b64[1:]
    tampered_token = f"{header_b64}.{payload_b64}.{tampered_signature}"

    response = await async_client.get("/auth/me", headers={"Authorization": f"Bearer {tampered_token}"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_rejects_missing_token(async_client):
    response = await async_client.get("/auth/me")
    assert response.status_code == 401


@pytest.mark.asyncio
# El agujero clásico de un JWT hecho a mano: un token que declara `alg: none`
# y no manda firma. La verificación nunca debe leer el algoritmo del header
# (HS256 queda fijo del lado del servidor), o cualquiera podría forjar un token de admin.
async def test_me_rejects_the_alg_none_forgery(async_client, db_session):
    user = await _create_user(db_session)
    header = security._b64url_encode(b'{"alg":"none","typ":"JWT"}')
    payload = security._b64url_encode(
        f'{{"sub":"{user.id}","exp":9999999999,"role":"admin"}}'.encode()
    )
    forged = f"{header}.{payload}."

    response = await async_client.get("/auth/me", headers={"Authorization": f"Bearer {forged}"})
    assert response.status_code == 401


@pytest.mark.asyncio
# Intento de escalar privilegios: reusar una firma real, pero cambiar el
# payload de abajo por uno que dice ser admin.
async def test_me_rejects_a_payload_swapped_under_a_valid_signature(async_client, db_session):
    user = await _create_user(db_session, role=UserRole.USER)
    token = security.create_access_token(subject=str(user.id), role=user.role.value)
    header_b64, _, signature_b64 = token.split(".")
    escalated_payload = security._b64url_encode(
        f'{{"sub":"{user.id}","exp":9999999999,"role":"admin"}}'.encode()
    )
    forged = f"{header_b64}.{escalated_payload}.{signature_b64}"

    response = await async_client.get("/auth/me", headers={"Authorization": f"Bearer {forged}"})
    assert response.status_code == 401
