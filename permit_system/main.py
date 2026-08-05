from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.auth_routes import router as auth_router
from src.api.permit_routes import router as permit_router
from src.infra.database.mysql_db import create_tables


app = FastAPI(title="Permit System API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    create_tables()


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(auth_router)
app.include_router(permit_router)
