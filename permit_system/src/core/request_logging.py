import json
import logging
import os
import time
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from pathlib import Path
from uuid import uuid4


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "event": record.getMessage(),
        }
        for key in ("request_id", "method", "path", "status_code", "duration_ms", "client_ip"):
            value = getattr(record, key, None)
            if value is not None:
                payload[key] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def get_request_logger() -> logging.Logger:
    """Returns a rotating, structured log without recording request bodies or tokens."""
    logger = logging.getLogger("permit.request")
    if logger.handlers:
        return logger

    log_dir = Path(os.getenv("LOG_DIR", "/app/logs"))
    log_dir.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(
        log_dir / "api-errors.jsonl",
        maxBytes=5 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    handler.setFormatter(_JsonFormatter())
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
    return logger


async def log_request(request, call_next):
    logger = get_request_logger()
    request_id = request.headers.get("X-Request-Id") or uuid4().hex
    started = time.perf_counter()
    client_ip = request.client.host if request.client else None
    details = {
        "request_id": request_id,
        "method": request.method,
        "path": request.url.path,
        "client_ip": client_ip,
    }
    try:
        response = await call_next(request)
    except Exception:
        logger.exception("request_exception", extra=details)
        raise

    response.headers["X-Request-Id"] = request_id
    if response.status_code >= 400:
        logger.warning(
            "request_error",
            extra={
                **details,
                "status_code": response.status_code,
                "duration_ms": round((time.perf_counter() - started) * 1000),
            },
        )
    return response
