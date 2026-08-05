from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.core.security import create_access_token, hash_password, verify_password
from src.infra.database.models import RoleModel, SecretariaModel, UserModel
from src.schemas.auth_schema import TokenResponse, UserSessionResponse
from src.schemas.user_schema import UserCreateRequest, UserResponse


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def authenticate(self, email: str, senha: str) -> TokenResponse:
        user = self.db.query(UserModel).filter(UserModel.email == email, UserModel.is_active.is_(True)).first()
        if not user or not verify_password(senha, user.senha_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email ou senha inválidos",
            )

        session = self._to_session(user)
        token = create_access_token(
            subject=str(user.id),
            claims={
                "role": session.role,
                "secretaria": session.secretaria,
            },
        )
        return TokenResponse(access_token=token, user=session)

    def create_user(self, payload: UserCreateRequest) -> UserResponse:
        existing = (
            self.db.query(UserModel)
            .filter((UserModel.email == payload.email) | (UserModel.cpf_cnpj == payload.cpf_cnpj))
            .first()
        )
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Usuário já cadastrado")

        role = self.db.query(RoleModel).filter(RoleModel.slug == payload.role).first()
        if not role:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Perfil inválido")

        secretaria = None
        if payload.secretaria:
            secretaria = self.db.query(SecretariaModel).filter(SecretariaModel.slug == payload.secretaria).first()
            if not secretaria:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Secretaria inválida")

        user = UserModel(
            tipo_pessoa=payload.tipo_pessoa,
            nome=payload.nome,
            sobrenome=payload.sobrenome,
            razao_social=payload.razao_social,
            cpf_cnpj=payload.cpf_cnpj,
            email=str(payload.email),
            senha_hash=hash_password(payload.senha),
            telefone=payload.telefone,
            endereco=payload.endereco,
            role_id=role.id,
            secretaria_id=secretaria.id if secretaria else None,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return self.to_response(user)

    @staticmethod
    def _to_session(user: UserModel) -> UserSessionResponse:
        return UserSessionResponse(
            id=user.id,
            nome=user.nome,
            email=user.email,
            role=user.role.slug,
            secretaria=user.secretaria.slug if user.secretaria else None,
        )

    @staticmethod
    def to_response(user: UserModel) -> UserResponse:
        return UserResponse(
            id=user.id,
            tipo_pessoa=user.tipo_pessoa,
            nome=user.nome,
            sobrenome=user.sobrenome,
            razao_social=user.razao_social,
            cpf_cnpj=user.cpf_cnpj,
            email=user.email,
            telefone=user.telefone,
            endereco=user.endereco,
            role=user.role.slug,
            secretaria=user.secretaria.slug if user.secretaria else None,
            is_active=user.is_active,
        )
