from typing import Annotated

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.security import InvalidTokenError, decode_access_token
from app.database.session import async_session_factory
from app.models.user import User, UserRole
from app.repositories import user_repository
from app.websocket.manager import manager

router = APIRouter()


# Es el equivalente de get_current_user, pero a mano: un navegador no puede
# mandar el header Authorization en la conexión de WebSocket, así que el
# token viaja como query parameter en su lugar.
async def _authenticate(token: str | None, db: AsyncSession) -> User | None:
    if token is None:
        return None
    try:
        payload = decode_access_token(token)
    except InvalidTokenError:
        return None

    user = await user_repository.get_by_id(db, payload.sub)
    if user is None or not user.is_active:
        return None
    return user


# Canal de solo envío: el server nunca devuelve eco de lo que recibe.
# Cualquier usuario autenticado ve telemetry_updated (igual que GET
# /telemetry); alert_created y alert_resolved solo llegan a conexiones admin
# (igual que GET /alerts).
@router.websocket("/ws/telemetry")
async def telemetry_ws(
    websocket: WebSocket,
    token: Annotated[str | None, Query()] = None,
) -> None:
    # La sesión se abre a mano y se cierra acá mismo, en vez de venir por
    # Depends(get_db): una dependencia con yield se libera recién cuando
    # retorna el endpoint, y este endpoint vive lo que dure el WebSocket.
    # Cada conexión abierta se quedaba con una conexión del pool (de 15) en
    # `idle in transaction` hasta desconectarse, y con el pool agotado hasta
    # el login empezaba a dar timeout. La base solo hace falta para autenticar.
    async with async_session_factory() as db:
        user = await _authenticate(token, db)

    if user is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket, is_admin=user.role == UserRole.ADMIN)
    try:
        while True:
            # Leer acá es solo cómo Starlette detecta una desconexión
            # prolija; lo que mande el cliente se ignora a propósito.
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
