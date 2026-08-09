from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


# Configuración central de la app, se carga desde el .env.
class Settings(BaseSettings):
    app_name: str = "IoT Fleet Monitor"

    database_url: str = "sqlite+aiosqlite:///./fleet.db"

    # secret_key firma los JWT. Cambiar el default antes de ir a producción.
    secret_key: str = "dev-secret-change-me"
    access_token_expire_minutes: int = 90

    # Puerto del dev server de Vite. docker-compose pasa el mismo valor por
    # CORS_ORIGINS, para que ambas formas de correr el stack coincidan.
    cors_origins: list[str] = ["http://localhost:5173"]

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


# Cacheado: una sola instancia de Settings por proceso.
@lru_cache
def get_settings() -> Settings:
    return Settings()
