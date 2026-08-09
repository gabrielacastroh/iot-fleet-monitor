# Auth a nivel router: se prueba `_authenticate` directo contra una fila real
# de la base, igual que el resto de la suite prueba la lógica de servicios —
# esta parte no necesita un socket.

import pytest

from app.auth.security import create_access_token
from app.websocket.router import _authenticate


@pytest.mark.asyncio
async def test_authenticate_accepts_a_valid_token(db_session, admin_headers):
    token = admin_headers["Authorization"].removeprefix("Bearer ")

    user = await _authenticate(token, db_session)

    assert user is not None
    assert user.role.value == "admin"


@pytest.mark.asyncio
async def test_authenticate_rejects_a_missing_token(db_session):
    assert await _authenticate(None, db_session) is None


@pytest.mark.asyncio
async def test_authenticate_rejects_a_malformed_token(db_session):
    assert await _authenticate("not-a-jwt", db_session) is None


@pytest.mark.asyncio
async def test_authenticate_rejects_a_forged_signature(db_session):
    token = create_access_token(subject="00000000-0000-0000-0000-000000000000", role="admin")
    tampered = token[:-4] + "abcd"

    assert await _authenticate(tampered, db_session) is None


@pytest.mark.asyncio
async def test_authenticate_rejects_an_unknown_user(db_session):
    # Un token bien formado y firmado, pero de un user id borrado (o que
    # nunca existió), no debe autenticar.
    token = create_access_token(subject="00000000-0000-0000-0000-000000000000", role="admin")

    assert await _authenticate(token, db_session) is None
