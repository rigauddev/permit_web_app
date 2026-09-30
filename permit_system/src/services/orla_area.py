import os

from sqlalchemy.orm import Session

from src.infra.database.models import ContentSettingModel

# Polígono inicial aproximado da faixa da Orla de Guaibim.
# O administrador pode substituí-lo em Gestão de conteúdo. A variável de
# ambiente continua como contingência para instalações sem banco configurado.
DEFAULT_ORLA_POLYGON = [
    (-13.2795, -38.9715),
    (-13.2795, -38.9570),
    (-13.2945, -38.9570),
    (-13.2945, -38.9715),
]
ORLA_POLYGON_SETTING = 'orla_guaibim_polygon'


def _parse_polygon(raw: str | None) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for item in (raw or '').split(';'):
        parts = [part.strip() for part in item.split(',')]
        if len(parts) != 2:
            continue
        try:
            points.append((float(parts[0]), float(parts[1])))
        except ValueError:
            continue
    return points if len(points) >= 3 else []


def orla_polygon(db: Session | None = None) -> list[tuple[float, float]]:
    if db is not None:
        setting = db.get(ContentSettingModel, ORLA_POLYGON_SETTING)
        configured = _parse_polygon(setting.value if setting else None)
        if configured:
            return configured
    configured = _parse_polygon(os.getenv('ORLA_GUAIBIM_POLYGON', '').strip())
    return configured or DEFAULT_ORLA_POLYGON


def is_inside_orla(
    latitude: str | None,
    longitude: str | None,
    db: Session | None = None,
) -> bool:
    try:
        lat = float(latitude or '')
        lon = float(longitude or '')
    except ValueError:
        return False
    polygon = orla_polygon(db)
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
