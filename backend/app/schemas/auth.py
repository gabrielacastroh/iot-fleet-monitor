from uuid import UUID

from pydantic import BaseModel

from app.models.user import UserRole


# Clase para la respuesta de /auth/login: el JWT que recibe el cliente.
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# Clase para el contenido del JWT ya decodificado, la usa security.py al validarlo.
class TokenPayload(BaseModel):
    sub: UUID
    exp: int
    role: UserRole
