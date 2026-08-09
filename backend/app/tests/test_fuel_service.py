# Tests unitarios de la predicción de combustible. Sin base de datos ni app:
# el servicio recibe lecturas simples, para eso está desacoplado.

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import pytest

from app.services.fuel_service import (
    AverageConsumptionStrategy,
    FuelPrediction,
    FuelSample,
    FuelService,
    PredictionStatus,
)

BASE_TIME = datetime(2026, 8, 7, 12, 0, tzinfo=timezone.utc)


# Reemplaza a un TelemetryReading real en los tests: tiene los mismos dos
# campos que necesita fuel_service, sin depender de la base de datos.
@dataclass(frozen=True)
class Sample:
    fuel_level: float
    recorded_at: datetime


# Arma una lista de lecturas a partir de pares (horas desde el inicio, nivel de combustible).
def samples(*points: tuple[float, float]) -> list[Sample]:
    return [
        Sample(fuel_level=level, recorded_at=BASE_TIME + timedelta(hours=offset))
        for offset, level in points
    ]


def test_predicts_autonomy_from_average_consumption():
    # Se gastaron 20 puntos en 2 horas = 10 por hora; quedan 50 = 5 horas.
    prediction = FuelService().evaluate(samples((0, 70), (1, 60), (2, 50)))

    assert prediction.status is PredictionStatus.OK
    assert prediction.consumption_per_hour == pytest.approx(10)
    assert prediction.hours_remaining == pytest.approx(5)
    assert prediction.should_alert is False


def test_flags_autonomy_under_one_hour():
    # 30 puntos por hora, quedan 12: son 24 minutos de autonomía.
    prediction = FuelService().evaluate(samples((0, 42), (1, 12)))

    assert prediction.hours_remaining == pytest.approx(0.4)
    assert prediction.should_alert is True


def test_exactly_one_hour_is_not_critical():
    # La regla es "menos de una hora": justo en el límite no debe alertar, o
    # el umbral se convertiría en silencio en "una hora o menos".
    prediction = FuelService().evaluate(samples((0, 20), (1, 10)))

    assert prediction.hours_remaining == pytest.approx(1)
    assert prediction.should_alert is False


def test_single_sample_cannot_measure_a_rate():
    prediction = FuelService().evaluate(samples((0, 5)))

    assert prediction.status is PredictionStatus.INSUFFICIENT_DATA
    assert prediction.hours_remaining is None
    # Poco combustible sin una tasa medible no debe alertar: dispararía en la
    # primera lectura de cada vehículo.
    assert prediction.should_alert is False


def test_empty_history_is_insufficient_data():
    prediction = FuelService().evaluate([])

    assert prediction.status is PredictionStatus.INSUFFICIENT_DATA
    assert prediction.should_alert is False


def test_idle_vehicle_reports_no_consumption():
    prediction = FuelService().evaluate(samples((0, 40), (1, 40), (2, 40)))

    assert prediction.status is PredictionStatus.NO_CONSUMPTION
    assert prediction.hours_remaining is None
    assert prediction.should_alert is False


def test_refuel_does_not_inflate_autonomy():
    # Gasta 10 en la primera hora, después se carga hasta 90. Contar la carga
    # como consumo negativo reportaría un tanque que nunca se vacía.
    prediction = FuelService().evaluate(samples((0, 50), (1, 40), (2, 90)))

    assert prediction.status is PredictionStatus.OK
    assert prediction.consumption_per_hour == pytest.approx(5)
    assert prediction.hours_remaining == pytest.approx(18)


def test_readings_out_of_order_are_sorted_before_measuring():
    # El repositorio devuelve las lecturas más nuevas primero, así que el
    # cálculo no puede depender del orden en que llegan.
    newest_first = samples((2, 50), (1, 60), (0, 70))

    assert FuelService().evaluate(newest_first).hours_remaining == pytest.approx(5)


def test_naive_timestamps_are_read_as_utc():
    # SQLite devuelve fechas sin zona horaria; mezclarlas con fechas que sí
    # tienen zona rompe la resta.
    naive = [
        Sample(fuel_level=60, recorded_at=BASE_TIME.replace(tzinfo=None)),
        Sample(
            fuel_level=50,
            recorded_at=(BASE_TIME + timedelta(hours=1)).replace(tzinfo=None),
        ),
    ]

    assert FuelService().evaluate(naive).hours_remaining == pytest.approx(5)


def test_simultaneous_readings_cannot_measure_a_rate():
    prediction = FuelService().evaluate(samples((0, 60), (0, 50)))

    assert prediction.status is PredictionStatus.INSUFFICIENT_DATA
    assert prediction.should_alert is False


def test_threshold_is_configurable():
    strategy = AverageConsumptionStrategy(critical_hours=6)
    prediction = FuelService(strategy).evaluate(samples((0, 70), (1, 60), (2, 50)))

    assert prediction.hours_remaining == pytest.approx(5)
    assert prediction.should_alert is True


def test_rejects_a_non_positive_threshold():
    with pytest.raises(ValueError):
        AverageConsumptionStrategy(critical_hours=0)


# Confirma que se puede enchufar un algoritmo de predicción distinto sin tocar FuelService.
def test_accepts_an_alternative_strategy():
    class AlwaysCritical:
        def predict(self, series: list[FuelSample]) -> FuelPrediction:
            return FuelPrediction(
                status=PredictionStatus.OK,
                fuel_level=series[-1].fuel_level,
                consumption_per_hour=99,
                hours_remaining=0.1,
                should_alert=True,
            )

    prediction = FuelService(AlwaysCritical()).evaluate(samples((0, 80), (1, 79)))

    assert prediction.should_alert is True
    assert prediction.hours_remaining == pytest.approx(0.1)


def test_prediction_is_immutable():
    prediction = FuelService().evaluate(samples((0, 70), (1, 60)))

    with pytest.raises(AttributeError):
        prediction.should_alert = True  # type: ignore[misc]
