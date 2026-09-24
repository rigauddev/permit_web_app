import os
import time

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import DatabaseError, IntegrityError
from sqlalchemy.orm import sessionmaker

from .models import Base

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./permit_system.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_tables():
    last_error = None
    for attempt in range(1, 6):
        try:
            Base.metadata.create_all(bind=engine)
            _ensure_user_email_unique_index()
            print("Tabelas criadas com sucesso!")
            return
        except DatabaseError as error:
            message = str(error).lower()
            if "concurrent ddl" not in message and "definition is being modified" not in message:
                raise
            last_error = error
            wait_seconds = min(attempt * 2, 10)
            print(f"DDL concorrente detectado; tentando novamente em {wait_seconds}s...")
            time.sleep(wait_seconds)
    if last_error:
        raise last_error


def _ensure_user_email_unique_index():
    """Aplica a unicidade de e-mail também em bancos já criados pelo MVP."""
    inspector = inspect(engine)
    indexes = inspector.get_indexes('usuarios')
    constraints = inspector.get_unique_constraints('usuarios')
    has_unique_email = any(
        item.get('unique') and item.get('column_names') == ['email']
        for item in [*indexes, *constraints]
    )
    if not has_unique_email:
        try:
            with engine.begin() as connection:
                connection.execute(text('CREATE UNIQUE INDEX uq_usuarios_email ON usuarios (email)'))
        except IntegrityError:
            # Bancos legados podem possuir duplicidades anteriores à regra.
            # A API impede novos casos; os registros antigos são tratados pela
            # gestão antes de ativar a restrição física no banco.
            print('Índice único de e-mail adiado: existem e-mails duplicados legados.')

if __name__ == "__main__":
    create_tables()
