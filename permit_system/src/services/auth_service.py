import re
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
from src.schemas.user_schema import UserAdminUpdateRequest, UserCreateRequest, UserResponse, UserSelfUpdateRequest
from src.services.email_service import build_mfa_email_html, send_email


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def start_login(self, identifier: str, senha: str, access_type: str | None = None, client_type: str = "web") -> LoginStartResponse:
        identifier = (identifier or "").strip()
        if access_type == "cidadao":
            document = self._only_digits(identifier)
            if not (self._is_valid_cpf(document) or self._is_valid_cnpj(document)):
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="CPF/CNPJ informado está incorreto.",
                )
            user = (
                self.db.query(UserModel)
                .filter(UserModel.cpf_cnpj == document, UserModel.is_active.is_(True))
                .first()
            )
        else:
            if "@" not in identifier:
                self._invalid_credentials()
            user = (
                self.db.query(UserModel)
                .filter(UserModel.email == identifier, UserModel.is_active.is_(True))
                .first()
            )
        if not user or not verify_password(senha, user.senha_hash):
            self._invalid_credentials()
        if access_type == "cidadao" and user.role.slug != "cidadao":
            self._invalid_credentials()
        if access_type == "interno" and user.role.slug == "cidadao":
            self._invalid_credentials()

        methods = self._available_mfa_methods(user)
        if not methods:
            token = self._create_session_token(user, client_type)
            return LoginStartResponse(
                mfa_required=False,
                access_token=token.access_token,
                user=token.user,
            )
        return LoginStartResponse(
            mfa_required=True,
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
            if not user.email:
                self._invalid_credentials()
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

        return self._create_session_token(user, client_type)

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
        if require_email_verification and payload.email:
            self._validate_email_verification_token(payload.email, payload.email_verification_token)

        role_slug = force_role or payload.role
        if role_slug == "cidadao" and not payload.termo_responsabilidade_aceito:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Aceite o termo de responsabilidade para criar a conta",
            )
        email = (payload.email or "").strip() or None
        if email and "@" not in email:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="E-mail inválido")
        if role_slug == "cidadao":
            document = self._validate_document(payload.cpf_cnpj, payload.tipo_pessoa)
            self._validate_citizen_registration_files(payload)
            existing = (
                self.db.query(UserModel)
                .filter(UserModel.cpf_cnpj == document)
                .first()
            )
            if existing:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="CPF/CNPJ já cadastrado")
        elif not email:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="E-mail é obrigatório para usuários internos.",
            )
        else:
            document = None
            existing = self.db.query(UserModel).filter(UserModel.email == email).first()
            if existing:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="E-mail já cadastrado")

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
            cpf_cnpj=document,
            email=email,
            senha_hash=hash_password(payload.senha),
            telefone=payload.telefone,
            endereco=payload.endereco,
            foto_usuario_nome=payload.foto_usuario_nome,
            foto_usuario_url=payload.foto_usuario_url,
            comprovante_residencia_nome=payload.comprovante_residencia_nome,
            comprovante_residencia_url=payload.comprovante_residencia_url,
            comprovante_residencia_tipo=payload.comprovante_residencia_tipo,
            comprovante_residencia_status=self._residence_proof_status(payload),
            comprovante_residencia_observacao=self._residence_proof_observation(payload),
            role_id=role.id,
            secretaria_id=secretaria.id if secretaria else None,
            mfa_email_enabled=bool(payload.mfa_email_enabled and email),
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return self.to_response(user)

    @staticmethod
    def _create_session_token(user: UserModel, client_type: str = "web") -> TokenResponse:
        session = AuthService._to_session(user)
        expires_delta = timedelta(days=5) if client_type == "app" else timedelta(hours=3)
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

    def update_current_user(self, user: UserModel, payload: UserSelfUpdateRequest) -> UserResponse:
        for field in ["nome", "sobrenome", "telefone", "endereco"]:
            value = getattr(payload, field)
            if value is not None:
                setattr(user, field, value)
        self.db.commit()
        self.db.refresh(user)
        return self.to_response(user)

    def update_user_by_admin(
        self,
        user_id: int,
        payload: UserAdminUpdateRequest,
        current_user: UserModel,
    ) -> UserResponse:
        user = self.db.query(UserModel).filter(UserModel.id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não encontrado")

        current_role = current_user.role.slug
        if current_role == "gestor_secretaria":
            if user.secretaria_id != current_user.secretaria_id:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
            if payload.role == "admin":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Gestor de secretaria não pode promover administrador",
                )

        for field in ["nome", "sobrenome", "telefone", "endereco", "email"]:
            value = getattr(payload, field)
            if value is not None:
                setattr(user, field, value)

        if payload.role is not None:
            role = self.db.query(RoleModel).filter(RoleModel.slug == payload.role, RoleModel.is_active.is_(True)).first()
            if not role:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Perfil inválido")
            if current_role == "gestor_secretaria" and role.slug == "admin":
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
            user.role_id = role.id

        if payload.secretaria is not None:
            secretaria = None
            if payload.secretaria:
                secretaria = (
                    self.db.query(SecretariaModel)
                    .filter(SecretariaModel.slug == payload.secretaria, SecretariaModel.is_active.is_(True))
                    .first()
                )
                if not secretaria:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Secretaria inválida")
            if current_role == "gestor_secretaria" and (
                not secretaria or secretaria.id != current_user.secretaria_id
            ):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
            user.secretaria_id = secretaria.id if secretaria else None

        if payload.is_active is not None and current_role == "admin":
            user.is_active = payload.is_active

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
        if not user.email:
            return "E-mail não informado"
        return AuthService._mask_email(user.email)

    @staticmethod
    def _mask_email(email: str) -> str:
        name, _, domain = email.partition("@")
        visible = name[:2] if len(name) > 2 else name[:1]
        return f"{visible}***@{domain}"

    @staticmethod
    def _only_digits(value: str | None) -> str:
        return re.sub(r"\D", "", value or "")

    @classmethod
    def _validate_document(cls, value: str | None, person_type: str) -> str:
        digits = cls._only_digits(value)
        is_valid = cls._is_valid_cnpj(digits) if person_type == "PJ" else cls._is_valid_cpf(digits)
        if not is_valid:
            label = "CNPJ" if person_type == "PJ" else "CPF"
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"{label} informado está incorreto.")
        return digits

    @staticmethod
    def _is_valid_cpf(value: str) -> bool:
        if len(value) != 11 or value == value[0] * 11:
            return False
        numbers = [int(digit) for digit in value]
        for size in (9, 10):
            total = sum(numbers[index] * (size + 1 - index) for index in range(size))
            digit = (total * 10) % 11
            if digit == 10:
                digit = 0
            if digit != numbers[size]:
                return False
        return True

    @staticmethod
    def _is_valid_cnpj(value: str) -> bool:
        if len(value) != 14 or value == value[0] * 14:
            return False
        numbers = [int(digit) for digit in value]
        weights = ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
        for offset, current_weights in enumerate(weights):
            total = sum(numbers[index] * current_weights[index] for index in range(len(current_weights)))
            digit = 11 - (total % 11)
            if digit >= 10:
                digit = 0
            if digit != numbers[12 + offset]:
                return False
        return True

    @staticmethod
    def _validate_citizen_registration_files(payload: UserCreateRequest) -> None:
        if not (payload.foto_usuario_nome or payload.foto_usuario_url):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Inclua uma foto do usuário para concluir o cadastro.",
            )
        if not (payload.comprovante_residencia_nome or payload.comprovante_residencia_url):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Inclua comprovante de residência em nome do usuário, pai ou mãe.",
            )
        proof_type = (payload.comprovante_residencia_tipo or "").strip().lower()
        if proof_type not in {"agua", "luz"}:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Serão aceitas somente contas de água ou luz como comprovante de residência.",
            )

    @staticmethod
    def _residence_proof_status(payload: UserCreateRequest) -> str:
        name = (payload.comprovante_residencia_nome or "").lower()
        proof_type = (payload.comprovante_residencia_tipo or "").lower()
        if any(term in name for term in ["agua", "água", "embasa"]) or any(term in name for term in ["luz", "energia", "coelba", "neoenergia"]):
            return "pre_validado"
        if proof_type in {"agua", "luz"}:
            return "pendente_validacao"
        return "recusado"

    @staticmethod
    def _residence_proof_observation(payload: UserCreateRequest) -> str | None:
        status_value = AuthService._residence_proof_status(payload)
        if status_value == "pre_validado":
            return "Nome do arquivo indica conta de água/luz. A validação final depende da leitura do documento."
        if status_value == "pendente_validacao":
            return "Documento aceito para análise. Leitura automática do conteúdo será integrada na etapa de OCR."
        return "Tipo de comprovante não permitido."

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
            foto_usuario_url=user.foto_usuario_url,
            comprovante_residencia_url=user.comprovante_residencia_url,
            comprovante_residencia_status=user.comprovante_residencia_status,
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
