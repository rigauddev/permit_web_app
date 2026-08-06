from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.permit_schema import (
    AttachmentResponse,
    CommentCreateRequest,
    CommentResponse,
    DamAttachmentRequest,
    PermitCreateRequest,
    PermitResponse,
    RequirementResponse,
    RequirementStatusUpdateRequest,
)
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


@router.get("/{request_id}", response_model=PermitResponse)
def get_permit_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return PermitService(db).get_request(request_id, current_user)


@router.post("/{request_id}/comments", response_model=CommentResponse)
def create_permit_comment(
    request_id: int,
    payload: CommentCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return PermitService(db).create_comment(request_id, payload, current_user)


@router.post("/{request_id}/dam-attachment", response_model=AttachmentResponse)
def attach_dam_to_permit_request(
    request_id: int,
    payload: DamAttachmentRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).attach_dam(request_id, payload, current_user)


@router.patch("/requirements/{requirement_id}/status", response_model=RequirementResponse)
def update_requirement_status(
    requirement_id: int,
    payload: RequirementStatusUpdateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).update_requirement_status(requirement_id, payload, current_user)
