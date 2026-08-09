# Calcula cuánta autonomía de combustible le queda a un vehículo, a partir de
# sus últimas lecturas. Solo hace cálculos: no consulta la base de datos ni
# sabe nada de la API.

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Protocol, Sequence

# Si quedan menos horas de autonomía que esto, se considera crítico y se avisa.
CRITICAL_AUTONOMY_HOURS = 1.0

# Con una sola lectura no se puede saber a qué ritmo se gasta combustible;
# hacen falta al menos dos para comparar.
MIN_SAMPLES = 2


# Datos mínimos que necesita una lectura para entrar al cálculo: cuánto
# combustible tenía y en qué momento se tomó.
class FuelSample(Protocol):
    fuel_level: float
    recorded_at: datetime


# Resultado de la predicción, aparte del número: si se pudo calcular bien
# (OK), si faltan lecturas para calcular (INSUFFICIENT_DATA), o si el
# vehículo no está gastando combustible ahora mismo, por ejemplo porque está
# parado (NO_CONSUMPTION).
class PredictionStatus(str, Enum):
    OK = "ok"
    INSUFFICIENT_DATA = "insufficient_data"
    NO_CONSUMPTION = "no_consumption"


# Lo que devuelve una predicción, ya armado y listo para usar.
@dataclass(frozen=True, slots=True)
class FuelPrediction:
    status: PredictionStatus
    fuel_level: float
    consumption_per_hour: float | None
    hours_remaining: float | None
    should_alert: bool


# El "molde" que tiene que cumplir cualquier forma de calcular la predicción:
# recibe una lista de lecturas y devuelve un FuelPrediction.
class FuelPredictionStrategy(Protocol):
    def predict(self, samples: Sequence[FuelSample]) -> FuelPrediction: ...


# La forma en la que hoy se calcula la autonomía: se mira cuánto combustible
# se gastó entre la primera y la última lectura, se saca un promedio por
# hora, y con ese promedio se calcula cuánto tiempo más puede durar.
#
# Ejemplo: hace 2 horas el tanque tenía 50%, ahora tiene 40% → se gastó 10%
# en 2 horas → 5% por hora → con 40% restante, quedan 8 horas de autonomía.
class AverageConsumptionStrategy:
    def __init__(self, critical_hours: float = CRITICAL_AUTONOMY_HOURS) -> None:
        if critical_hours <= 0:
            raise ValueError("critical_hours must be positive")
        self._critical_hours = critical_hours

    def predict(self, samples: Sequence[FuelSample]) -> FuelPrediction:
        # Paso 1: ordenar las lecturas de más vieja a más nueva.
        ordered = sorted(samples, key=lambda sample: _as_utc(sample.recorded_at))

        # Paso 2: con una sola lectura no hay con qué comparar, no se puede calcular nada.
        if len(ordered) < MIN_SAMPLES:
            return _unknown(
                fuel_level=ordered[-1].fuel_level if ordered else 0.0,
                status=PredictionStatus.INSUFFICIENT_DATA,
            )

        current_fuel = ordered[-1].fuel_level
        # Paso 3: cuánto tiempo pasó entre la primera y la última lectura.
        elapsed_hours = _elapsed_hours(ordered[0], ordered[-1])

        # Si todas las lecturas llegaron en el mismo instante, no hay tiempo
        # transcurrido y tampoco se puede calcular una tasa de consumo.
        if elapsed_hours <= 0:
            return _unknown(current_fuel, PredictionStatus.INSUFFICIENT_DATA)

        # Paso 4: cuánto combustible se gastó en ese tiempo.
        consumed = _total_consumption(ordered)
        if consumed <= 0:
            # No bajó nada (vehículo parado, o se cargó combustible): a este
            # ritmo el tanque nunca se vacía, así que no hay autonomía que
            # calcular ni nada de qué avisar.
            return _unknown(current_fuel, PredictionStatus.NO_CONSUMPTION)

        # Paso 5: gasto por hora, y con eso, cuántas horas más puede durar
        # el combustible que queda ahora.
        consumption_per_hour = consumed / elapsed_hours
        hours_remaining = current_fuel / consumption_per_hour

        return FuelPrediction(
            status=PredictionStatus.OK,
            fuel_level=current_fuel,
            consumption_per_hour=consumption_per_hour,
            hours_remaining=hours_remaining,
            # Si la autonomía calculada cae por debajo del umbral crítico, hay que avisar.
            should_alert=hours_remaining < self._critical_hours,
        )


# Es lo que el resto de la app usa para pedir una predicción de combustible.
class FuelService:
    def __init__(self, strategy: FuelPredictionStrategy | None = None) -> None:
        self._strategy = strategy or AverageConsumptionStrategy()

    def evaluate(self, samples: Sequence[FuelSample]) -> FuelPrediction:
        return self._strategy.predict(samples)


# Se usa cuando no hay forma de calcular la autonomía todavía. No avisa nada,
# porque no es lo mismo "sin combustible" que "sin datos suficientes".
def _unknown(fuel_level: float, status: PredictionStatus) -> FuelPrediction:
    return FuelPrediction(
        status=status,
        fuel_level=fuel_level,
        consumption_per_hour=None,
        hours_remaining=None,
        should_alert=False,
    )


# Suma cuánto bajó el nivel de combustible entre lecturas consecutivas.
def _total_consumption(ordered: Sequence[FuelSample]) -> float:
    return sum(
        max(previous.fuel_level - current.fuel_level, 0.0)
        for previous, current in zip(ordered, ordered[1:])
    )


# Horas transcurridas entre la primera y la última lectura.
def _elapsed_hours(first: FuelSample, last: FuelSample) -> float:
    delta = _as_utc(last.recorded_at) - _as_utc(first.recorded_at)
    return delta.total_seconds() / 3600


# Deja toda fecha en UTC antes de compararlas o restarlas. 
def _as_utc(moment: datetime) -> datetime:
    if moment.tzinfo is None:
        return moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc)
