from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.infra.database.models import HomeContentCardModel, UserModel
from src.schemas.content_schema import HomeContentCardRequest, HomeContentCardResponse


PREFEITURA_SCOPE = "prefeitura"
MAX_ACTIVE_CARDS_PER_SCOPE = 5


class ContentService:
    def __init__(self, db: Session):
        self.db = db

    def list_cards(self, current_user: UserModel | None = None) -> list[HomeContentCardResponse]:
        query = self.db.query(HomeContentCardModel)
        if current_user is None or current_user.role.slug == "cidadao":
            query = query.filter(HomeContentCardModel.is_active.is_(True))
        elif current_user.role.slug == "gestor_secretaria":
            if not current_user.secretaria:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Gestor sem secretaria vinculada")
            query = query.filter(HomeContentCardModel.scope == current_user.secretaria.slug)
        return [
            self.to_response(card)
            for card in query.order_by(
                HomeContentCardModel.scope,
                HomeContentCardModel.display_order,
                HomeContentCardModel.created_at.desc(),
            ).all()
        ]

    def create_card(
        self,
        payload: HomeContentCardRequest,
        current_user: UserModel,
    ) -> HomeContentCardResponse:
        scope = self._resolve_scope(payload.scope, current_user)
        if payload.is_active:
            self._ensure_active_limit(scope)

        card = HomeContentCardModel(
            scope=scope,
            title=payload.title.strip(),
            body=payload.body.strip(),
            image_url=payload.image_url.strip(),
            display_order=payload.display_order,
            is_active=payload.is_active,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
        self.db.add(card)
        self.db.commit()
        self.db.refresh(card)
        return self.to_response(card)

    def update_card(
        self,
        card_id: int,
        payload: HomeContentCardRequest,
        current_user: UserModel,
    ) -> HomeContentCardResponse:
        card = self.db.query(HomeContentCardModel).filter(HomeContentCardModel.id == card_id).first()
        if not card:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card não encontrado")
        self._ensure_can_manage_scope(card.scope, current_user)

        new_scope = self._resolve_scope(payload.scope, current_user)
        if payload.is_active and (not card.is_active or card.scope != new_scope):
            self._ensure_active_limit(new_scope)

        card.scope = new_scope
        card.title = payload.title.strip()
        card.body = payload.body.strip()
        card.image_url = payload.image_url.strip()
        card.display_order = payload.display_order
        card.is_active = payload.is_active
        card.updated_by = current_user.id
        self.db.commit()
        self.db.refresh(card)
        return self.to_response(card)

    def _ensure_active_limit(self, scope: str) -> None:
        active_count = (
            self.db.query(HomeContentCardModel)
            .filter(
                HomeContentCardModel.scope == scope,
                HomeContentCardModel.is_active.is_(True),
            )
            .count()
        )
        if active_count >= MAX_ACTIVE_CARDS_PER_SCOPE:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cada prefeitura ou secretaria pode ter no máximo 5 cards ativos no carrossel",
            )

    @staticmethod
    def _resolve_scope(scope: str | None, current_user: UserModel) -> str:
        role = current_user.role.slug
        if role == "admin":
            return (scope or PREFEITURA_SCOPE).strip()
        if role == "gestor_secretaria":
            if not current_user.secretaria:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Gestor sem secretaria vinculada")
            return current_user.secretaria.slug
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")

    @staticmethod
    def _ensure_can_manage_scope(scope: str, current_user: UserModel) -> None:
        if current_user.role.slug == "admin":
            return
        if current_user.role.slug == "gestor_secretaria" and current_user.secretaria and scope == current_user.secretaria.slug:
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")

    @staticmethod
    def to_response(card: HomeContentCardModel) -> HomeContentCardResponse:
        return HomeContentCardResponse(
            id=card.id,
            scope=card.scope,
            title=card.title,
            body=card.body,
            image_url=card.image_url,
            display_order=card.display_order,
            is_active=card.is_active,
        )
