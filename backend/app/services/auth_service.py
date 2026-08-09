import logging

from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.security import create_access_token, hash_password, verify_password
from app.core.exceptions import AuthenticationError, EmailAlreadyRegisteredError
from app.models.user import User, UserRole
from app.repositories import user_repository
from app.schemas.auth import Token
from app.schemas.user import UserCreate

logger = logging.getLogger(__name__)

_INVALID_CREDENTIALS_MESSAGE = "Incorrect email or password"


# Normaliza el email para que "User@Mail.com" y "user@mail.com" sean el mismo usuario.
def normalize_email(email: str) -> str:
    return email.strip().lower()


# Registra un usuario nuevo. El rol siempre queda en USER
async def register(db: AsyncSession, payload: UserCreate) -> User:
    email = normalize_email(payload.email)

    if await user_repository.get_by_email(db, email) is not None:
        logger.warning("Failed signup attempt: email already registered", extra={"email": email})
        raise EmailAlreadyRegisteredError("Email already registered")

    user = User(
        name=payload.name.strip(),
        email=email,
        hashed_password=hash_password(payload.password),
        role=UserRole.USER,
    )
    return await user_repository.create(db, user)


# Valida email y contraseña. Mismo mensaje de error para usuario inexistente,
# cuenta inactiva o contraseña incorrecta, para no darle pistas a un atacante.
async def authenticate_user(db: AsyncSession, email: str, password: str) -> User:
    user = await user_repository.get_by_email(db, normalize_email(email))

    if user is None:
        logger.warning("Failed login attempt: user not found", extra={"email": email})
        raise AuthenticationError(_INVALID_CREDENTIALS_MESSAGE)

    if not user.is_active:
        logger.warning("Failed login attempt: inactive account", extra={"email": email})
        raise AuthenticationError(_INVALID_CREDENTIALS_MESSAGE)

    if not verify_password(password, user.hashed_password):
        logger.warning("Failed login attempt: wrong password", extra={"email": email})
        raise AuthenticationError(_INVALID_CREDENTIALS_MESSAGE)

    return user


# Valida credenciales y devuelve el JWT de acceso.
async def login(db: AsyncSession, email: str, password: str) -> Token:
    user = await authenticate_user(db, email, password)
    access_token = create_access_token(subject=str(user.id), role=user.role.value)
    return Token(access_token=access_token)
