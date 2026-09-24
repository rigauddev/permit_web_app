from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.content_schema import (
    BannerApprovalRequest,
    ContentSettingsRequest,
    ContentSettingsResponse,
    EmailTemplatesResponse,
    HomeContentCardRequest,
    HomeContentCardResponse,
    ServiceConfigRequest,
    ServiceConfigResponse,
    TourismPointRequest,
    TourismPointResponse,
)
from src.services.content_service import ContentService


router = APIRouter(prefix="/home-content", tags=["home-content"])


@router.get("", response_model=list[HomeContentCardResponse])
def list_home_content(
    mine: bool = False,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).list_cards(current_user, mine=mine)


@router.post("", response_model=HomeContentCardResponse)
def create_home_content(
    payload: HomeContentCardRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).create_card(payload, current_user)


@router.get("/settings", response_model=ContentSettingsResponse)
def get_content_settings(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).get_settings(current_user)


@router.put("/settings", response_model=ContentSettingsResponse)
def update_content_settings(
    payload: ContentSettingsRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return ContentService(db).update_settings(payload, current_user)


@router.get('/email-templates', response_model=EmailTemplatesResponse)
def get_email_templates(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles('admin')),
):
    return ContentService(db).get_email_templates(current_user)


@router.put('/email-templates', response_model=EmailTemplatesResponse)
def update_email_templates(
    payload: EmailTemplatesResponse,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles('admin')),
):
    return ContentService(db).update_email_templates(payload, current_user)


@router.get("/tourism-points", response_model=list[TourismPointResponse])
def list_tourism_points(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).list_tourism_points(current_user)


@router.post("/tourism-points", response_model=TourismPointResponse)
def create_tourism_point(
    payload: TourismPointRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    return ContentService(db).create_tourism_point(payload, current_user)


@router.put("/tourism-points/{point_id}", response_model=TourismPointResponse)
def update_tourism_point(
    point_id: int,
    payload: TourismPointRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    return ContentService(db).update_tourism_point(point_id, payload, current_user)


@router.delete("/tourism-points/{point_id}", status_code=204)
def delete_tourism_point(
    point_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    ContentService(db).delete_tourism_point(point_id, current_user)


@router.patch("/{card_id}/approval", response_model=HomeContentCardResponse)
def approve_establishment_banner(
    card_id: int,
    payload: BannerApprovalRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    return ContentService(db).approve_banner(card_id, payload.approved, current_user)


@router.put("/{card_id}", response_model=HomeContentCardResponse)
def update_home_content(
    card_id: int,
    payload: HomeContentCardRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).update_card(card_id, payload, current_user)


@router.delete("/{card_id}", status_code=204)
def delete_home_content(
    card_id: int,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    ContentService(db).delete_card(card_id, current_user)


@router.get("/services", response_model=list[ServiceConfigResponse])
def list_services(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).list_services()


@router.put("/services/{service_key}", response_model=ServiceConfigResponse)
def update_service(
    service_key: str,
    payload: ServiceConfigRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin")),
):
    return ContentService(db).update_service(service_key, payload.is_active, current_user)
