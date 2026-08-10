import random
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.core.security import (
    create_access_token,
    create_email_verification_token,
    create_mfa_challenge_token,
    decode_token,
    hash_password,
    verify_password,
)
from src.infra.database.models import EmailVerificationModel, RoleModel, SecretariaModel, UserModel
from src.schemas.auth_schema import (
    EmailVerificationConfirmResponse,
    EmailVerificationStartResponse,
    LoginStartResponse,
    MfaGenerateResponse,
    TokenResponse,
    UserSessionResponse,
)
from src.schemas.user_schema import UserCreateRequest, UserResponse
from src.services.email_service import build_mfa_email_html, send_email


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def start_login(self, email: str, senha: str, access_type: str | None = None) -> LoginStartResponse:
        user = self.db.query(UserModel).filter(UserModel.email == email, UserModel.is_active.is_(True)).first()
        if not user or not verify_password(senha, user.senha_hash):
            self._invalid_credentials()
        if access_type == "cidadao" and user.role.slug != "cidadao":
            self._invalid_credentials()
        if access_type == "interno" and user.role.slug == "cidadao":
            self._invalid_credentials()

        methods = self._available_mfa_methods(user)
        if not methods:
            methods = ["email"]
        return LoginStartResponse(
            challenge_token=create_mfa_challenge_token(str(user.id)),
            available_methods=methods,
            default_method=methods[0],
        )

    def generate_mfa_code(self, challenge_token: str, method: str) -> MfaGenerateResponse:
        user = self._get_user_from_challenge(challenge_token)
        methods = self._available_mfa_methods(user)
        if method not in methods:
            self._invalid_credentials()

        code = f"{random.randint(0, 999999):06d}"
        user.mfa_code_hash = hash_password(code)
        user.mfa_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        self.db.commit()
        if method == "email":
            status_message = send_email(
                user.email,
                "Código de acesso ao sistema da Prefeitura",
                f"Seu código de acesso é {code}. Ele expira em 5 minutos.",
                html=build_mfa_email_html(code, user.secretaria),
            )
            print(f"[MFA EMAIL] {user.email}: {status_message}")

        return MfaGenerateResponse(
            method=method,
            delivery=self._mask_delivery(user, method),
            dev_code=code,
        )

    def verify_mfa_code(self, challenge_token: str, method: str, code: str, client_type: str = "web") -> TokenResponse:
        user = self._get_user_from_challenge(challenge_token)
        methods = self._available_mfa_methods(user)
        expires_at = user.mfa_code_expires_at
        if method not in methods:
            self._invalid_credentials()
        if not user.mfa_code_hash or not expires_at:
            self._invalid_credentials()
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            self._invalid_credentials()
        if not verify_password(code, user.mfa_code_hash):
            self._invalid_credentials()

        user.mfa_code_hash = None
        user.mfa_code_expires_at = None
        self.db.commit()

        session = self._to_session(user)
        expires_delta = timedelta(days=2) if client_type == "app" else timedelta(hours=2)
        token = create_access_token(
            subject=str(user.id),
            claims={
                "role": session.role,
                "secretaria": session.secretaria,
                "client_type": client_type,
            },
            expires_delta=expires_delta,
        )
        return TokenResponse(access_token=token, user=session)

    def start_email_verification(self, email: str, purpose: str = "register") -> EmailVerificationStartResponse:
        existing_user = self.db.query(UserModel).filter(UserModel.email == email).first()
        if purpose == "register" and existing_user:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="E-mail já cadastrado")

        code = f"{random.randint(0, 999999):06d}"
        verification = EmailVerificationModel(
            email=email,
            purpose=purpose,
            code_hash=hash_password(code),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        )
        self.db.add(verification)
        self.db.commit()
        status_message = send_email(
            email,
            "Código de validação de e-mail",
            f"Seu código de validação é {code}. Ele expira em 10 minutos.",
            html=build_mfa_email_html(code),
        )
        print(f"[EMAIL VERIFICATION] {email}: {status_message}")

        return EmailVerificationStartResponse(
            email=email,
            delivery=self._mask_email(email),
            dev_code=code,
        )

    def confirm_email_verification(self, email: str, code: str, purpose: str = "register") -> EmailVerificationConfirmResponse:
        verification = (
            self.db.query(EmailVerificationModel)
            .filter(
                EmailVerificationModel.email == email,
                EmailVerificationModel.purpose == purpose,
                EmailVerificationModel.verified_at.is_(None),
            )
            .order_by(EmailVerificationModel.created_at.desc())
            .first()
        )
        if not verification:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Código não gerado")

        expires_at = verification.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Código expirado")
        if not verify_password(code, verification.code_hash):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Código inválido")

        verification.verified_at = datetime.now(timezone.utc)
        self.db.commit()

        return EmailVerificationConfirmResponse(
            email=email,
            verification_token=create_email_verification_token(email),
        )

    def create_user(
        self,
        payload: UserCreateRequest,
        force_role: str | None = None,
        force_secretaria: str | None = None,
        require_email_verification: bool = False,
    ) -> UserResponse:
        if require_email_verification:
            self._validate_email_verification_token(payload.email, payload.email_verification_token)

        role_slug = force_role or payload.role
        if require_email_verification and role_slug == "cidadao" and not payload.termo_responsabilidade_aceito:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Aceite o termo de responsabilidade para criar a conta",
            )

        existing = (
            self.db.query(UserModel)
            .filter((UserModel.email == payload.email) | (UserModel.cpf_cnpj == payload.cpf_cnpj))
            .first()
        )
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Usuário já cadastrado")

        secretaria_slug = force_secretaria if force_secretaria is not None else payload.secretaria

        role = self.db.query(RoleModel).filter(RoleModel.slug == role_slug).first()
        if not role:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Perfil inválido")

        secretaria = None
        if secretaria_slug:
            secretaria = self.db.query(SecretariaModel).filter(SecretariaModel.slug == secretaria_slug).first()
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
            mfa_email_enabled=True,
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
            cpf_cnpj=user.cpf_cnpj,
            telefone=user.telefone,
            endereco=user.endereco,
            role=user.role.slug,
            secretaria=user.secretaria.slug if user.secretaria else None,
            permissions=AuthService._permission_slugs(user),
        )

    def _get_user_from_challenge(self, challenge_token: str) -> UserModel:
        try:
            payload = decode_token(challenge_token)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciais inválidas") from exc
        if payload.get("purpose") != "mfa":
            self._invalid_credentials()
        user = self.db.query(UserModel).filter(UserModel.id == int(payload["sub"]), UserModel.is_active.is_(True)).first()
        if not user:
            self._invalid_credentials()
        return user

    @staticmethod
    def _invalid_credentials() -> None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciais inválidas")

    @staticmethod
    def _available_mfa_methods(user: UserModel) -> list[str]:
        methods = []
        if user.mfa_email_enabled:
            methods.append("email")
        if user.mfa_totp_enabled:
            methods.append("totp")
        return methods

    @staticmethod
    def _mask_delivery(user: UserModel, method: str) -> str:
        if method != "email":
            return method
        return AuthService._mask_email(user.email)

    @staticmethod
    def _mask_email(email: str) -> str:
        name, _, domain = email.partition("@")
        visible = name[:2] if len(name) > 2 else name[:1]
        return f"{visible}***@{domain}"

    @staticmethod
    def _validate_email_verification_token(email: str, verification_token: str | None) -> None:
        if not verification_token:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Valide o e-mail antes do cadastro")
        try:
            payload = decode_token(verification_token)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Validação de e-mail inválida") from exc
        if payload.get("purpose") != "email_verification" or payload.get("sub") != email:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Validação de e-mail inválida")

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
            permissions=AuthService._permission_slugs(user),
            is_active=user.is_active,
        )

    @staticmethod
    def _permission_slugs(user: UserModel) -> list[str]:
        if not user.role:
            return []
        return sorted(
            role_permission.permission.slug
            for role_permission in user.role.permissions
            if role_permission.permission and role_permission.permission.is_active
        )
