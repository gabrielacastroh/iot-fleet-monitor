# Toda la lógica de alertas: cuándo se crean, cuándo se resuelven, cuándo se
# listan. Ningún otro módulo escribe directo en la tabla de alertas.

import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AlertNotFoundError
from app.models.alert import Alert, AlertType
from app.repositories import alert_repository
from app.schemas.alert import AlertCountQuery, AlertCreate, AlertFilters, AlertQuery
from app.services import device_service
from app.services.fuel_service import FuelPrediction, PredictionStatus
from app.websocket.events import AlertCreatedEvent, AlertResolvedEvent
from app.websocket.publisher import EventPublisher, NullEventPublisher, default_event_publisher

logger = logging.getLogger(__name__)


class AlertService:
    def __init__(self, publisher: EventPublisher | None = None) -> None:
        self._publisher = publisher or NullEventPublisher()

    # Lista alertas según filtros, con paginación.
    async def list_alerts(self, db: AsyncSession, filters: AlertQuery) -> list[Alert]:
        return await alert_repository.list_filtered(
            db,
            device_id=filters.device_id,
            alert_type=filters.alert_type,
            is_resolved=filters.is_resolved,
            limit=filters.limit,
        )

    # Cuenta el total de alertas que matchean los filtros. Es lo que usa el
    # badge de "alertas activas" del dashboard, porque list_alerts solo
    # devuelve una página y no serviría para contar el total real.
    async def count_alerts(self, db: AsyncSession, filters: AlertCountQuery) -> int:
        return await alert_repository.count_filtered(
            db,
            device_id=filters.device_id,
            alert_type=filters.alert_type,
            is_resolved=filters.is_resolved,
        )

    # Lista las alertas de un dispositivo puntual. Primero valida que el
    # dispositivo exista, para devolver 404 en vez de una lista vacía que
    # se podría confundir con "sin alertas".
    async def list_device_alerts(
        self, db: AsyncSession, device_id: uuid.UUID, filters: AlertFilters
    ) -> list[Alert]:
        await device_service.get_device(db, device_id)

        return await alert_repository.list_filtered(
            db,
            device_id=device_id,
            alert_type=filters.alert_type,
            is_resolved=filters.is_resolved,
            limit=filters.limit,
        )

    # Busca una alerta por id, o lanza error si no existe.
    async def get_alert(self, db: AsyncSession, alert_id: uuid.UUID) -> Alert:
        alert = await alert_repository.get_by_id(db, alert_id)
        if alert is None:
            raise AlertNotFoundError(f"Alert '{alert_id}' not found")
        return alert

    # Crea una alerta nueva, o devuelve la que ya estaba abierta. Un camión
    # con combustible bajo por una hora debe generar UNA alerta, no una por
    # cada lectura de telemetría que llega.
    async def raise_alert(self, db: AsyncSession, payload: AlertCreate) -> Alert:
        active = await alert_repository.get_active(
            db, device_id=payload.device_id, alert_type=payload.alert_type
        )
        if active is not None:
            return active

        created = await alert_repository.create(
            db,
            Alert(
                device_id=payload.device_id,
                alert_type=payload.alert_type,
                message=payload.message,
            ),
        )
        logger.info(
            "Alert raised",
            extra={
                "alert_id": str(created.id),
                "device_id": str(created.device_id),
                "alert_type": created.alert_type.value,
            },
        )
        await self._publisher.publish(AlertCreatedEvent.from_alert(created))
        return created

    # Marca una alerta como resuelta. Es idempotente a propósito
    async def resolve_alert(self, db: AsyncSession, alert_id: uuid.UUID) -> Alert:
        alert = await self.get_alert(db, alert_id)
        return await self._resolve(db, alert, reason="manual")

    # Revisa si la alerta de combustible bajo de un dispositivo sigue
    # vigente según la última predicción, y la abre o cierra según corresponda.
    async def sync_fuel_alert(
        self,
        db: AsyncSession,
        device_id: uuid.UUID,
        prediction: FuelPrediction,
    ) -> Alert | None:
        if prediction.should_alert:
            return await self.raise_alert(
                db,
                AlertCreate(
                    device_id=device_id,
                    alert_type=AlertType.LOW_FUEL,
                    message=_low_fuel_message(prediction),
                ),
            )

        active = await alert_repository.get_active(
            db, device_id=device_id, alert_type=AlertType.LOW_FUEL
        )
        if active is None:
            return None

        if prediction.status is not PredictionStatus.OK:
            return active

        await self._resolve(db, active, reason="autonomy_recovered")
        return None

    # Marca la alerta como resuelta si no lo estaba, y avisa por WebSocket.
    async def _resolve(self, db: AsyncSession, alert: Alert, *, reason: str) -> Alert:
        if alert.is_resolved:
            return alert

        alert.is_resolved = True
        resolved = await alert_repository.save(db, alert)
        logger.info(
            "Alert resolved",
            extra={"alert_id": str(resolved.id), "reason": reason},
        )
        await self._publisher.publish(AlertResolvedEvent.from_alert(resolved))
        return resolved


# Instancia compartida, conectada al canal de WebSocket real.
alert_service = AlertService(default_event_publisher)


# Arma el texto de la alerta de combustible bajo, en español porque así se
# muestra tal cual en el dashboard, el menú de notificaciones y la pantalla de alertas.
def _low_fuel_message(prediction: FuelPrediction) -> str:
    hours = prediction.hours_remaining or 0.0
    return (
        f"Autonomía por debajo de una hora: quedan {hours * 60:.0f} min "
        f"con {prediction.fuel_level:.1f}% de combustible"
    )
