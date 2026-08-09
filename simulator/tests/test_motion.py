import pytest

from simulator.motion import bearing_to, distance_km, step


def test_step_moving_north_increases_latitude():
    lat, lon = step(0.0, 0.0, 0, 111.0)
    assert lat == pytest.approx(1.0, abs=0.01)
    assert lon == pytest.approx(0.0, abs=0.001)


def test_step_moving_east_increases_longitude():
    lat, lon = step(0.0, 0.0, 90, 111.0)
    assert lon == pytest.approx(1.0, abs=0.01)
    assert lat == pytest.approx(0.0, abs=0.001)


def test_zero_distance_does_not_move():
    lat, lon = step(4.65, -74.05, 123.0, 0.0)
    assert (lat, lon) == pytest.approx((4.65, -74.05))


def test_distance_km_matches_a_known_step():
    lat2, lon2 = step(0.0, 0.0, 0, 50.0)
    assert distance_km(0.0, 0.0, lat2, lon2) == pytest.approx(50.0, rel=0.01)


def test_distance_km_of_the_same_point_is_zero():
    assert distance_km(4.65, -74.05, 4.65, -74.05) == pytest.approx(0.0, abs=1e-9)


def test_bearing_to_north_is_zero():
    assert bearing_to(0.0, 0.0, 1.0, 0.0) == pytest.approx(0.0, abs=0.5)


def test_bearing_to_east_is_ninety():
    assert bearing_to(0.0, 0.0, 0.0, 1.0) == pytest.approx(90.0, abs=0.5)


def test_step_then_bearing_back_points_the_opposite_way():
    lat2, lon2 = step(4.65, -74.05, 40.0, 20.0)
    forward = bearing_to(4.65, -74.05, lat2, lon2)
    backward = bearing_to(lat2, lon2, 4.65, -74.05)
    assert (backward - forward) % 360 == pytest.approx(180.0, abs=1.0)
