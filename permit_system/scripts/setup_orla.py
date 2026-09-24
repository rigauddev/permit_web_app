"""Idempotent setup limited to Orla tables and responsible secretarias."""
import sys
from pathlib import Path
from sqlalchemy import inspect, text
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.infra.database.mysql_db import engine, SessionLocal
from src.infra.database.models import SecretariaModel
from src.infra.database.models.orla_model import OrlaAccount, OrlaVehicle, OrlaAccess


def setup():
    for model in (OrlaAccount, OrlaVehicle, OrlaAccess):
        model.__table__.create(engine, checkfirst=True)
    inspector = inspect(engine)
    if "orla_vehicles" in inspector.get_table_names():
        columns = {column["name"] for column in inspector.get_columns("orla_vehicles")}
        if "brand" not in columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE orla_vehicles ADD COLUMN brand VARCHAR(80) NOT NULL DEFAULT 'Nao informado'"))
        if "establishment_name" not in columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE orla_vehicles ADD COLUMN establishment_name VARCHAR(150) NULL"))
    with SessionLocal() as db:
        for slug, nome in (("dmtran", "DMTRAN"), ("guarda_civil", "Guarda Municipal")):
            if not db.query(SecretariaModel).filter_by(slug=slug).first():
                db.add(
                    SecretariaModel(
                        slug=slug,
                        nome=nome,
                        descricao='Fiscalização do acesso à orla de Guaibim',
                    )
                )
        db.commit()
    print('Secretarias responsáveis e tabelas do serviço Acesso à Orla prontas.')


if __name__ == '__main__':
    setup()
