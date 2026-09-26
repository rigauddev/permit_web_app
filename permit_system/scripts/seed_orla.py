"""Seed enxuto para homologação do serviço Acesso à Orla."""

from seed import (
    SessionLocal,
    create_tables,
    ensure_orla_inn_columns,
    ensure_orla_vehicle_columns,
    ensure_secretaria_columns,
    ensure_user_columns,
    seed_orla_service,
    seed_permissions,
    seed_roles,
    seed_secretarias,
    seed_users,
)


def main():
    create_tables()
    ensure_user_columns()
    ensure_secretaria_columns()
    ensure_orla_inn_columns()
    ensure_orla_vehicle_columns()
    db = SessionLocal()
    try:
        roles = seed_roles(db)
        seed_permissions(db, roles)
        secretarias = seed_secretarias(db)
        users = seed_users(db, roles, secretarias)
        seed_orla_service(db, roles, users)
        db.commit()
        print("Seed exclusivo da Orla executado com sucesso.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
