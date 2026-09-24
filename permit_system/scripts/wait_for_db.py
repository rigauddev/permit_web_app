import time
import sys
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.infra.database.mysql_db import engine


def main() -> None:
    last_error: Exception | None = None
    for _ in range(60):
        try:
            with engine.connect() as connection:
                connection.execute(text("SELECT 1"))
            return
        except SQLAlchemyError as error:
            last_error = error
            time.sleep(2)
    raise SystemExit(f"Banco de dados indisponível após aguardar: {last_error}")


if __name__ == "__main__":
    main()
