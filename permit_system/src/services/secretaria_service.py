from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.infra.database.models import SecretariaModel, UserModel
from src.schemas.secretaria_schema import SecretariaRequest, SecretariaResponse


class SecretariaService:
    def __init__(self, db: Session):
        self.db = db

    def list_secretarias(self, current_user: UserModel) -> list[SecretariaResponse]:
        query = self.db.query(SecretariaModel)
        if current_user.role.slug == "gestor_secretaria":
            query = query.filter(SecretariaModel.id == current_user.secretaria_id)
        return [self._to_response(item) for item in query.order_by(SecretariaModel.nome.asc()).all()]

    def create_secretaria(self, payload: SecretariaRequest, current_user: UserModel) -> SecretariaResponse:
        self._ensure_admin(current_user)
        existing = self.db.query(SecretariaModel).filter(SecretariaModel.slug == payload.slug).first()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Secretaria já cadastrada")
        secretaria = SecretariaModel(**payload.model_dump())
        self.db.add(secretaria)
        self.db.commit()
        self.db.refresh(secretaria)
        return self._to_response(secretaria)

    def update_secretaria(
        self,
        secretaria_id: int,
        payload: SecretariaRequest,
        current_user: UserModel,
    ) -> SecretariaResponse:
        secretaria = self.db.query(SecretariaModel).filter(SecretariaModel.id == secretaria_id).first()
        if not secretaria:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Secretaria não encontrada")
        if current_user.role.slug == "gestor_secretaria" and current_user.secretaria_id != secretaria.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        if current_user.role.slug != "admin" and current_user.role.slug != "gestor_secretaria":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        existing = (
            self.db.query(SecretariaModel)
            .filter(SecretariaModel.slug == payload.slug, SecretariaModel.id != secretaria_id)
            .first()
        )
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Secretaria já cadastrada")

        data = payload.model_dump()
        if current_user.role.slug == "gestor_secretaria":
            data["slug"] = secretaria.slug
            data["nome"] = secretaria.nome
            data["is_active"] = secretaria.is_active
        for key, value in data.items():
            setattr(secretaria, key, value)
        self.db.commit()
        self.db.refresh(secretaria)
        return self._to_response(secretaria)

    @staticmethod
    def _ensure_admin(current_user: UserModel) -> None:
        if current_user.role.slug != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")

    @staticmethod
    def _to_response(secretaria: SecretariaModel) -> SecretariaResponse:
        return SecretariaResponse(
            id=secretaria.id,
            slug=secretaria.slug,
            nome=secretaria.nome,
            descricao=secretaria.descricao,
            email=secretaria.email,
            logo_url=secretaria.logo_url,
            email_header_text=secretaria.email_header_text,
            document_header_text=secretaria.document_header_text,
            document_footer_text=secretaria.document_footer_text,
            is_active=secretaria.is_active,
            created_at=secretaria.created_at,
        )
