from fastapi import APIRouter

from app.api.routes import alerts, devices, health, telemetry

# Junta los routers de cada recurso en uno solo para montarlo en main.py.
api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(devices.router)
api_router.include_router(telemetry.router)
api_router.include_router(alerts.router)
