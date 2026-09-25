import os

# Polígono inicial aproximado da faixa da Orla de Guaibim.
# Pode ser sobrescrito por ORLA_GUAIBIM_POLYGON no formato:
# "lat,lon;lat,lon;lat,lon"
DEFAULT_ORLA_POLYGON = [
    (-13.2795, -38.9715),
    (-13.2795, -38.9570),
    (-13.2945, -38.9570),
    (-13.2945, -38.9715),
]


def _polygon_from_env() -> list[tuple[float, float]]:
    raw = os.getenv('ORLA_GUAIBIM_POLYGON', '').strip()
    if not raw:
        return DEFAULT_ORLA_POLYGON
    points: list[tuple[float, float]] = []
    for item in raw.split(';'):
        parts = [part.strip() for part in item.split(',')]
        if len(parts) != 2:
            continue
        try:
            points.append((float(parts[0]), float(parts[1])))
        except ValueError:
            continue
    return points if len(points) >= 3 else DEFAULT_ORLA_POLYGON


def is_inside_orla(latitude: str | None, longitude: str | None) -> bool:
    try:
        lat = float(latitude or '')
        lon = float(longitude or '')
    except ValueError:
        return False
    polygon = _polygon_from_env()
    inside = False
    j = len(polygon) - 1
    for i, (lat_i, lon_i) in enumerate(polygon):
        lat_j, lon_j = polygon[j]
        intersects = ((lon_i > lon) != (lon_j > lon)) and (
            lat < (lat_j - lat_i) * (lon - lon_i) / ((lon_j - lon_i) or 1e-12) + lat_i
        )
        if intersects:
            inside = not inside
        j = i
    return inside
