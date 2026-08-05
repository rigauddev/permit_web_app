from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.permit_schema import PermitCreateRequest, PermitResponse
from src.services.permit_service import PermitService


router = APIRouter(prefix="/permit-requests", tags=["permit-requests"])


@router.post("", response_model=PermitResponse)
def create_permit_request(
    payload: PermitCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("cidadao", "admin")),
):
    return PermitService(db).create_request(payload, current_user)


@router.get("", response_model=list[PermitResponse])
def list_permit_requests(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return PermitService(db).list_requests(current_user)
