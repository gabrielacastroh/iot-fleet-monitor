import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Index, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


# Enum con los tipos de alerta posibles.
class AlertType(str, enum.Enum):
    LOW_FUEL = "low_fuel"


# Alerta generada para un dispositivo (hoy, solo por combustible bajo).
class Alert(Base):
    __tablename__ = "alerts"
    # Optimiza la consulta típica: alertas abiertas de un dispositivo.
    __table_args__ = (Index("ix_alerts_device_is_resolved", "device_id", "is_resolved"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    device_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("devices.id"))
    alert_type: Mapped[AlertType] = mapped_column(Enum(AlertType))
    message: Mapped[str] = mapped_column(String(255))
    is_resolved: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    device = relationship("Device", back_populates="alerts")