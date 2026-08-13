from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.permit_schema import (
    AttachmentResponse,
    AttachmentCreateRequest,
    AuthorizationTemplateRequest,
    AuthorizationTemplateResponse,
    CommentCreateRequest,
    CommentResponse,
    DamAttachmentRequest,
    EventCredentialResponse,
    EventCredentialRevokeRequest,
    EventCredentialValidationResponse,
    EventPublicRangeRequest,
    EventPublicRangeResponse,
    InspectionCompleteRequest,
    InspectionScheduleRequest,
    PermitCancelRequest,
    PermitCreateRequest,
    PermitResponse,
    QuestionCreateRequest,
    RequirementAttachmentRequest,
    QuestionResponse,
    RequirementResponse,
    RequirementStatusUpdateRequest,
)
from src.services.permit_service import PermitService


router = APIRouter(prefix="/permit-requests", tags=["permit-requests"])
credential_router = APIRouter(prefix="/event-credentials", tags=["event-credentials"])


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


@router.get("/authorization-template", response_model=AuthorizationTemplateResponse)
def get_authorization_template(
    db: Session = Depends(get_db),
    _: UserModel = Depends(get_current_user),
):
    return PermitService(db).get_authorization_template()


@router.put("/authorization-template", response_model=AuthorizationTemplateResponse)
def update_authorization_template(
    payload: AuthorizationTemplateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return PermitService(db).update_authorization_template(payload, current_user)


@router.get("/question-definitions", response_model=list[QuestionResponse])
def list_question_definitions(
    db: Session = Depends(get_db),
    _: UserModel = Depends(get_current_user),
):
    return PermitService(db).list_question_definitions()


@router.get("/public-ranges", response_model=list[EventPublicRangeResponse])
def list_public_ranges(
    db: Session = Depends(get_db),
    _: UserModel = Depends(get_current_user),
):
    return PermitService(db).list_public_ranges()


@router.post("/public-ranges", response_model=EventPublicRangeResponse)
def create_public_range(
    payload: EventPublicRangeRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return PermitService(db).create_public_range(payload, current_user)


@router.put("/public-ranges/{range_id}", response_model=EventPublicRangeResponse)
def update_public_range(
    range_id: int,
    payload: EventPublicRangeRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return PermitService(db).update_public_range(range_id, payload, current_user)


@router.delete("/public-ranges/{range_id}", status_code=204)
def delete_public_range(
    range_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    PermitService(db).delete_public_range(range_id, current_user)


@router.post("/question-definitions", response_model=QuestionResponse)
def create_question_definition(
    payload: QuestionCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return PermitService(db).create_question_definition(payload, current_user)


@router.put("/question-definitions/{question_id}", response_model=QuestionResponse)
def update_question_definition(
    question_id: int,
    payload: QuestionCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return PermitService(db).update_question_definition(question_id, payload, current_user)


@router.delete("/question-definitions/{question_id}", status_code=204)
def delete_question_definition(
    question_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    PermitService(db).delete_question_definition(question_id, current_user)


@router.get("/event-map", response_model=list[PermitResponse])
def list_event_map_requests(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).list_event_map_requests(current_user)


@router.get("/{request_id}", response_model=PermitResponse)
def get_permit_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return PermitService(db).get_request(request_id, current_user)


@router.patch("/{request_id}/cancel", response_model=PermitResponse)
def cancel_permit_request(
    request_id: int,
    payload: PermitCancelRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("cidadao", "admin")),
):
    return PermitService(db).cancel_request(request_id, payload, current_user)


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


@router.post("/{request_id}/dam-payment-proof", response_model=AttachmentResponse)
def attach_dam_payment_proof_to_permit_request(
    request_id: int,
    payload: AttachmentCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("cidadao")),
):
    return PermitService(db).attach_dam_payment_proof(request_id, payload, current_user)


@router.post("/{request_id}/requirement-attachment", response_model=AttachmentResponse)
def attach_requirement_document_to_permit_request(
    request_id: int,
    payload: RequirementAttachmentRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return PermitService(db).attach_requirement_document(request_id, payload, current_user)


@router.post("/{request_id}/final-permit-attachment", response_model=EventCredentialResponse)
def attach_final_permit_to_request(
    request_id: int,
    payload: AttachmentCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).attach_final_permit(request_id, payload, current_user)


@router.post("/{request_id}/issue-authorization", response_model=EventCredentialResponse)
def issue_permit_authorization(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).issue_authorization(request_id, current_user)


@router.get("/{request_id}/authorization", response_model=EventCredentialResponse)
def get_permit_authorization(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return PermitService(db).get_authorization(request_id, current_user)


@router.patch("/requirements/{requirement_id}/status", response_model=RequirementResponse)
def update_requirement_status(
    requirement_id: int,
    payload: RequirementStatusUpdateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).update_requirement_status(requirement_id, payload, current_user)


@router.patch("/requirements/{requirement_id}/inspection-schedule", response_model=RequirementResponse)
def schedule_requirement_inspection(
    requirement_id: int,
    payload: InspectionScheduleRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).schedule_inspection(requirement_id, payload, current_user)


@router.patch("/requirements/{requirement_id}/inspection-complete", response_model=RequirementResponse)
def complete_requirement_inspection(
    requirement_id: int,
    payload: InspectionCompleteRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).complete_inspection(requirement_id, payload, current_user)


@credential_router.get("/{codigo_publico}/validate", response_model=EventCredentialValidationResponse)
def validate_event_credential(
    codigo_publico: str,
    t: str,
    db: Session = Depends(get_db),
):
    return PermitService(db).validate_event_credential(codigo_publico, t)


@credential_router.post("/{credential_id}/revoke", response_model=EventCredentialResponse)
def revoke_event_credential(
    credential_id: int,
    payload: EventCredentialRevokeRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria", "operador_secretaria")),
):
    return PermitService(db).revoke_event_credential(credential_id, payload, current_user)
