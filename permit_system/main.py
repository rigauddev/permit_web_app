import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from src.api.orla_routes import router as orla_router
from src.api.auth_routes import router as auth_router
from src.api.content_routes import router as content_router
from src.api.permit_routes import credential_router, router as permit_router
from src.api.permission_routes import router as permission_router
from src.api.secretaria_routes import router as secretaria_router
from src.api.upload_routes import router as upload_router
from src.core.request_logging import log_request
from src.infra.database.mysql_db import create_tables


app = FastAPI(title="Permit System API", version="0.1.0")


@app.middleware("http")
async def request_error_logging(request, call_next):
    return await log_request(request, call_next)

default_cors = "http://localhost:8081,http://127.0.0.1:8081,http://localhost:3000,http://127.0.0.1:3000"
public_base_url = os.getenv("PUBLIC_BASE_URL", "").strip()
if public_base_url:
    default_cors = f"{default_cors},{public_base_url}"

raw_cors_origins = os.getenv("CORS_ORIGINS") or default_cors
cors_origins = [
    origin.strip()
    for origin in raw_cors_origins.split(",")
    if origin.strip()
]
cors_origin_regex = (
    os.getenv("CORS_ORIGIN_REGEX")
    or r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?$"
).strip()

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=cors_origin_regex,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.on_event("startup")
def startup():
    create_tables()


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(orla_router)
app.include_router(auth_router)
app.include_router(content_router)
app.include_router(permission_router)
app.include_router(secretaria_router)
app.include_router(permit_router)
app.include_router(credential_router)
upload_root = os.getenv("UPLOAD_ROOT", "/app/uploads")
os.makedirs(upload_root, exist_ok=True)
app.include_router(upload_router)
app.mount("/uploads", StaticFiles(directory=upload_root), name="uploads")
