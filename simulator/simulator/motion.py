"""Pure geometry. No I/O, no randomness sourced here — callers pass in
whatever heading or distance they rolled, so every function is deterministic
and trivial to test on its own.
"""

import math

EARTH_RADIUS_KM = 6371.0
KM_PER_DEGREE_LAT = 111.0


def step(
    latitude: float, longitude: float, heading_degrees: float, distance_km: float
) -> tuple[float, float]:
    """Moves a point `distance_km` along `heading_degrees` (0 = north,
    clockwise). Equirectangular approximation: accurate enough at the scale of
    one fleet's operating radius, far simpler than a full geodesic solve."""
    heading_rad = math.radians(heading_degrees)
    lat_rad = math.radians(latitude)

    delta_lat = (distance_km / KM_PER_DEGREE_LAT) * math.cos(heading_rad)
    km_per_degree_lon = KM_PER_DEGREE_LAT * max(math.cos(lat_rad), 0.01)
    delta_lon = (distance_km / km_per_degree_lon) * math.sin(heading_rad)

    return latitude + delta_lat, longitude + delta_lon


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance. Used only to check whether a vehicle has wandered
    outside its operating radius — the one place actual accuracy over a
    possibly-large gap matters."""
    lat1_r, lon1_r, lat2_r, lon2_r = (math.radians(v) for v in (lat1, lon1, lat2, lon2))
    dlat = lat2_r - lat1_r
    dlon = lon2_r - lon1_r
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def bearing_to(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Compass bearing from point 1 to point 2, in degrees, 0 = north,
    clockwise."""
    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    dlon_r = math.radians(lon2 - lon1)
    x = math.sin(dlon_r) * math.cos(lat2_r)
    y = math.cos(lat1_r) * math.sin(lat2_r) - math.sin(lat1_r) * math.cos(lat2_r) * math.cos(dlon_r)
    return math.degrees(math.atan2(x, y)) % 360
