import os
import time

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.exc import DatabaseError
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

if __name__ == "__main__":
    create_tables()
