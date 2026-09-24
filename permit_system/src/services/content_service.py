import json

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.infra.database.models import ContentSettingModel, HomeContentCardModel, ServiceConfigModel, TourismPointModel, UserModel
from src.schemas.content_schema import (
    ContentSettingsRequest,
    ContentSettingsResponse,
    HomeContentCardRequest,
    HomeContentCardResponse,
    ServiceConfigResponse,
    TourismPointRequest,
    TourismPointResponse,
)


PREFEITURA_SCOPE = "prefeitura"
MAX_ACTIVE_CARDS_PER_SCOPE = 5
BUSINESS_CATEGORIES = {"pousada_hotel", "restaurante", "quiosque"}
ESTABLISHMENT_SCOPE_PREFIX = "establishment:"
DEFAULT_SERVICES = {
    "alvara_evento": {
        "title": "Alvará de Evento",
        "description": "Solicitação de autorização para festas e eventos.",
        "is_active": True,
    },
    "acesso_orla": {
        "title": "Acesso à Orla",
        "description": "Cadastro e validação de veículos na Orla de Guaibim.",
        "is_active": True,
    },
    "alvara_funcionamento": {
        "title": "Alvará de Funcionamento",
        "description": "Solicitação e acompanhamento de alvará de funcionamento.",
        "is_active": False,
    },
    "iptu": {
        "title": "IPTU",
        "description": "Consulta e serviços relacionados ao IPTU.",
        "is_active": False,
    },
}
DEFAULT_CONTENT_SETTINGS = {
    "event_map_title": "Mapa de eventos autorizados",
    "event_map_description": "Consulte os eventos autorizados por período e abra a rota de cada local.",
    "event_map_editor_secretarias": "[]",
}
DEFAULT_TOURISM_POINTS = [
    ("Ponta do Curral", "Ponto natural e encontro com o mar", "Extremo da faixa turística", "Atrativos", -13.2678, -38.9535, .83, .21),
    ("Guaibimzinho", "Praia tranquila para banho e caminhada", "Lado sul de Guaibim", "Praia", -13.3026, -38.9722, .23, .70),
    ("Igreja de Guaibim", "Referência histórica e religiosa local", "Centro do povoado", "Religioso", -13.2874, -38.9660, .47, .55),
    ("Praça da Orla", "Eventos, feira e apresentações", "Orla principal", "Eventos", -13.2849, -38.9608, .51, .37),
]


class ContentService:
    def __init__(self, db: Session):
        self.db = db

    def list_cards(self, current_user: UserModel | None = None, mine: bool = False) -> list[HomeContentCardResponse]:
        query = self.db.query(HomeContentCardModel)
        if mine:
            if not current_user or not self._is_establishment_user(current_user):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Área disponível para estabelecimentos turísticos")
            query = query.filter(HomeContentCardModel.scope == self._establishment_scope(current_user))
        elif current_user is None or current_user.role.slug == "cidadao":
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
        is_establishment = scope.startswith(ESTABLISHMENT_SCOPE_PREFIX)
        is_active = False if is_establishment else payload.is_active
        if is_active:
            self._ensure_active_limit(scope)

        card = HomeContentCardModel(
            scope=scope,
            title=payload.title.strip(),
            body=payload.body.strip(),
            image_url=payload.image_url.strip(),
            display_order=payload.display_order,
            is_active=is_active,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
        self.db.add(card)
        self.db.commit()
        self.db.refresh(card)
        return self.to_response(card)

    def list_services(self) -> list[ServiceConfigResponse]:
        self._ensure_default_services()
        rows = self.db.query(ServiceConfigModel).order_by(ServiceConfigModel.title).all()
        return [self.service_to_response(row) for row in rows]

    def update_service(self, key: str, is_active: bool, current_user: UserModel) -> ServiceConfigResponse:
        if current_user.role.slug != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente administrador pode ativar ou desativar serviços")
        self._ensure_default_services()
        row = self.db.query(ServiceConfigModel).filter(ServiceConfigModel.key == key).first()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Serviço não encontrado")
        row.is_active = is_active
        row.updated_by = current_user.id
        self.db.commit()
        self.db.refresh(row)
        return self.service_to_response(row)

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
        card.is_active = False if self._is_establishment_user(current_user) else payload.is_active
        card.updated_by = current_user.id
        self.db.commit()
        self.db.refresh(card)
        return self.to_response(card)

    def approve_banner(self, card_id: int, approved: bool, current_user: UserModel) -> HomeContentCardResponse:
        if current_user.role.slug != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente o administrador pode aprovar banners")
        card = self.db.query(HomeContentCardModel).filter(HomeContentCardModel.id == card_id).first()
        if not card or not card.scope.startswith(ESTABLISHMENT_SCOPE_PREFIX):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner de estabelecimento não encontrado")
        if approved:
            self._ensure_active_limit(card.scope)
        card.is_active = approved
        card.updated_by = current_user.id
        self.db.commit()
        self.db.refresh(card)
        return self.to_response(card)

    def delete_card(self, card_id: int, current_user: UserModel) -> None:
        card = self.db.query(HomeContentCardModel).filter(HomeContentCardModel.id == card_id).first()
        if not card:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner não encontrado")
        self._ensure_can_manage_scope(card.scope, current_user)
        self.db.delete(card)
        self.db.commit()

    def get_settings(self, current_user: UserModel) -> ContentSettingsResponse:
        self._ensure_default_settings()
        values = {row.key: row.value for row in self.db.query(ContentSettingModel).all()}
        editors = self._decode_editors(values.get("event_map_editor_secretarias", "[]"))
        role = current_user.role.slug
        secretaria = current_user.secretaria.slug if current_user.secretaria else None
        can_edit = role == "admin" or (role == "gestor_secretaria" and secretaria in editors)
        return ContentSettingsResponse(
            event_map_title=values["event_map_title"],
            event_map_description=values["event_map_description"],
            event_map_editor_secretarias=editors,
            can_edit_event_map=can_edit,
            can_manage_editors=role == "admin",
        )

    def update_settings(self, payload: ContentSettingsRequest, current_user: UserModel) -> ContentSettingsResponse:
        current = self.get_settings(current_user)
        if not current.can_edit_event_map:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sua secretaria não pode editar o card do mapa de eventos")
        editor_secretarias = payload.event_map_editor_secretarias
        if current_user.role.slug != "admin":
            editor_secretarias = current.event_map_editor_secretarias
        values = {
            "event_map_title": payload.event_map_title.strip(),
            "event_map_description": payload.event_map_description.strip(),
            "event_map_editor_secretarias": json.dumps(sorted(set(editor_secretarias))),
        }
        for key, value in values.items():
            row = self.db.query(ContentSettingModel).filter(ContentSettingModel.key == key).first()
            if row:
                row.value = value
                row.updated_by = current_user.id
            else:
                self.db.add(ContentSettingModel(key=key, value=value, updated_by=current_user.id))
        self.db.commit()
        return self.get_settings(current_user)

    def list_tourism_points(self, current_user: UserModel) -> list[TourismPointResponse]:
        self._ensure_default_tourism_points()
        query = self.db.query(TourismPointModel)
        if current_user.role.slug == "cidadao":
            query = query.filter(TourismPointModel.is_active.is_(True))
        return [self.tourism_point_to_response(row) for row in query.order_by(TourismPointModel.display_order, TourismPointModel.title).all()]

    def create_tourism_point(self, payload: TourismPointRequest, current_user: UserModel) -> TourismPointResponse:
        if current_user.role.slug != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente o administrador pode editar o mapa turístico")
        row = TourismPointModel(**payload.model_dump(), created_by=current_user.id, updated_by=current_user.id)
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return self.tourism_point_to_response(row)

    def update_tourism_point(self, point_id: int, payload: TourismPointRequest, current_user: UserModel) -> TourismPointResponse:
        if current_user.role.slug != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente o administrador pode editar o mapa turístico")
        row = self.db.query(TourismPointModel).filter(TourismPointModel.id == point_id).first()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ponto turístico não encontrado")
        for key, value in payload.model_dump().items():
            setattr(row, key, value)
        row.updated_by = current_user.id
        self.db.commit()
        self.db.refresh(row)
        return self.tourism_point_to_response(row)

    def delete_tourism_point(self, point_id: int, current_user: UserModel) -> None:
        if current_user.role.slug != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente o administrador pode editar o mapa turístico")
        row = self.db.query(TourismPointModel).filter(TourismPointModel.id == point_id).first()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ponto turístico não encontrado")
        self.db.delete(row)
        self.db.commit()

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

    def _ensure_default_services(self) -> None:
        changed = False
        for key, data in DEFAULT_SERVICES.items():
            existing = self.db.query(ServiceConfigModel).filter(ServiceConfigModel.key == key).first()
            if existing:
                continue
            self.db.add(ServiceConfigModel(
                key=key,
                title=data["title"],
                description=data["description"],
                is_active=bool(data.get("is_active", True)),
            ))
            changed = True
        if changed:
            self.db.commit()

    def _ensure_default_settings(self) -> None:
        changed = False
        for key, value in DEFAULT_CONTENT_SETTINGS.items():
            if self.db.query(ContentSettingModel).filter(ContentSettingModel.key == key).first():
                continue
            self.db.add(ContentSettingModel(key=key, value=value))
            changed = True
        if changed:
            self.db.commit()

    def _ensure_default_tourism_points(self) -> None:
        if self.db.query(TourismPointModel).count() > 0:
            return
        for order, item in enumerate(DEFAULT_TOURISM_POINTS):
            self.db.add(TourismPointModel(
                title=item[0], detail=item[1], place=item[2], category=item[3],
                latitude=item[4], longitude=item[5], marker_x=item[6], marker_y=item[7],
                display_order=order, is_active=True,
            ))
        self.db.commit()

    @staticmethod
    def _decode_editors(value: str) -> list[str]:
        try:
            decoded = json.loads(value)
            return [str(item) for item in decoded] if isinstance(decoded, list) else []
        except (TypeError, ValueError):
            return []

    @staticmethod
    def _resolve_scope(scope: str | None, current_user: UserModel) -> str:
        role = current_user.role.slug
        if role == "admin":
            return (scope or PREFEITURA_SCOPE).strip()
        if ContentService._is_establishment_user(current_user):
            return ContentService._establishment_scope(current_user)
        if role == "gestor_secretaria":
            if not current_user.secretaria:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Gestor sem secretaria vinculada")
            return current_user.secretaria.slug
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")

    @staticmethod
    def _ensure_can_manage_scope(scope: str, current_user: UserModel) -> None:
        if current_user.role.slug == "admin":
            return
        if ContentService._is_establishment_user(current_user) and scope == ContentService._establishment_scope(current_user):
            return
        if current_user.role.slug == "gestor_secretaria" and current_user.secretaria and scope == current_user.secretaria.slug:
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")

    @staticmethod
    def _is_establishment_user(current_user: UserModel) -> bool:
        return bool(
            current_user.role
            and current_user.role.slug == "cidadao"
            and current_user.business_category in BUSINESS_CATEGORIES
        )

    @staticmethod
    def _establishment_scope(current_user: UserModel) -> str:
        return f"{ESTABLISHMENT_SCOPE_PREFIX}{current_user.id}"

    @staticmethod
    def to_response(card: HomeContentCardModel) -> HomeContentCardResponse:
        is_establishment = card.scope.startswith(ESTABLISHMENT_SCOPE_PREFIX)
        return HomeContentCardResponse(
            id=card.id,
            scope=card.scope,
            title=card.title,
            body=card.body,
            image_url=card.image_url,
            display_order=card.display_order,
            is_active=card.is_active,
            approval_status=("aprovado" if card.is_active else "aguardando_aprovacao") if is_establishment else ("ativo" if card.is_active else "inativo"),
            owner_name=card.creator.nome if is_establishment and card.creator else None,
        )

    @staticmethod
    def tourism_point_to_response(row: TourismPointModel) -> TourismPointResponse:
        return TourismPointResponse(
            id=row.id,
            title=row.title,
            detail=row.detail,
            place=row.place,
            category=row.category,
            latitude=row.latitude,
            longitude=row.longitude,
            marker_x=row.marker_x,
            marker_y=row.marker_y,
            display_order=row.display_order,
            is_active=bool(row.is_active),
        )

    @staticmethod
    def service_to_response(row: ServiceConfigModel) -> ServiceConfigResponse:
        return ServiceConfigResponse(
            key=row.key,
            title=row.title,
            description=row.description,
            is_active=bool(row.is_active),
        )
