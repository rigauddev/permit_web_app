from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.secretaria_schema import SecretariaRequest, SecretariaResponse
from src.services.secretaria_service import SecretariaService


router = APIRouter(prefix="/secretarias", tags=["secretarias"])


@router.get("", response_model=list[SecretariaResponse])
def list_secretarias(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return SecretariaService(db).list_secretarias(current_user)


@router.post("", response_model=SecretariaResponse)
def create_secretaria(
    payload: SecretariaRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    return SecretariaService(db).create_secretaria(payload, current_user)


@router.put("/{secretaria_id}", response_model=SecretariaResponse)
def update_secretaria(
    secretaria_id: int,
    payload: SecretariaRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return SecretariaService(db).update_secretaria(secretaria_id, payload, current_user)


@router.delete("/{secretaria_id}", status_code=204)
def delete_secretaria(
    secretaria_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    SecretariaService(db).delete_secretaria(secretaria_id, current_user)
