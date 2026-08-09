import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta, timezone

from passlib.context import CryptContext
from pydantic import ValidationError

from app.core.config import get_settings
from app.schemas.auth import TokenPayload

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Se lanza cuando el JWT está mal formado, tiene firma inválida o expiró.
class InvalidTokenError(Exception):
    pass


# Compara una contraseña en texto plano contra su hash bcrypt.
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


# Genera el hash bcrypt de una contraseña, para guardar en la DB.
def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


# Firma con HMAC-SHA256 usando la secret_key de la app.
def _sign(signing_input: bytes) -> bytes:
    return hmac.new(settings.secret_key.encode("utf-8"), signing_input, hashlib.sha256).digest()


# Arma el JWT a mano: base64url(header).base64url(payload).base64url(firma).
def create_access_token(subject: str, role: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=settings.access_token_expire_minutes)
    payload: dict[str, str | int] = {
        "sub": subject,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
        "role": role,
    }

    header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature_b64 = _b64url_encode(_sign(f"{header_b64}.{payload_b64}".encode("ascii")))

    return f"{header_b64}.{payload_b64}.{signature_b64}"


# Verifica el JWT a mano: recalcula la firma HMAC-SHA256 y la compara en
# tiempo constante, después chequea expiración. El `alg` del header nunca
# se usa para verificar, HS256 queda fijo del lado del servidor.
def decode_access_token(token: str) -> TokenPayload:
    parts = token.split(".")
    if len(parts) != 3:
        raise InvalidTokenError("Malformed token")
    header_b64, payload_b64, signature_b64 = parts

    try:
        signature = _b64url_decode(signature_b64)
    except ValueError as exc:
        raise InvalidTokenError("Malformed token signature") from exc

    expected_signature = _sign(f"{header_b64}.{payload_b64}".encode("ascii"))
    if not hmac.compare_digest(expected_signature, signature):
        raise InvalidTokenError("Invalid token signature")

    try:
        raw_payload = json.loads(_b64url_decode(payload_b64))
    except (ValueError, json.JSONDecodeError) as exc:
        raise InvalidTokenError("Malformed token payload") from exc

    exp = raw_payload.get("exp")
    if not isinstance(exp, int):
        raise InvalidTokenError("Missing required claims")

    if int(time.time()) >= exp:
        raise InvalidTokenError("Token has expired")

    try:
        return TokenPayload(**raw_payload)
    except ValidationError as exc:
        raise InvalidTokenError("Invalid token claims") from exc
