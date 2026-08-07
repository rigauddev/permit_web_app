from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.content_schema import HomeContentCardRequest, HomeContentCardResponse
from src.services.content_service import ContentService


router = APIRouter(prefix="/home-content", tags=["home-content"])


@router.get("", response_model=list[HomeContentCardResponse])
def list_home_content(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    return ContentService(db).list_cards(current_user)


@router.post("", response_model=HomeContentCardResponse)
def create_home_content(
    payload: HomeContentCardRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return ContentService(db).create_card(payload, current_user)


@router.put("/{card_id}", response_model=HomeContentCardResponse)
def update_home_content(
    card_id: int,
    payload: HomeContentCardRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    return ContentService(db).update_card(card_id, payload, current_user)
