import re
import random
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from src.core.security import (
    create_access_token,
    create_email_verification_token,
    create_mfa_challenge_token,
    decode_token,
    hash_password,
    verify_password,
)
from src.infra.database.models import EmailVerificationModel, OrlaInn, OrlaVehicle, RoleModel, SecretariaModel, UserModel
from src.schemas.auth_schema import (
    ChangePasswordRequest,
    EmailVerificationConfirmResponse,
    EmailVerificationStartResponse,
    LoginStartResponse,
    MfaGenerateResponse,
    TokenResponse,
    UserSessionResponse,
)
from src.schemas.user_schema import UserAdminUpdateRequest, UserCreateRequest, UserResponse, UserSelfUpdateRequest
from src.services.email_service import build_mfa_email_html, render_configured_email_template, send_email
from src.services.orla_area import is_inside_orla


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def start_login(self, identifier: str, senha: str, access_type: str | None = None, client_type: str = "web") -> LoginStartResponse:
        identifier = (identifier or "").strip()
        normalized_identifier = identifier.lower()
        document = self._only_digits(identifier)
        access_type = access_type or "cidadao"
        if access_type == "cidadao":
            filters = []
            if "@" in normalized_identifier:
                filters.append(func.lower(UserModel.email) == normalized_identifier)
            if document and (self._is_valid_cpf(document) or self._is_valid_cnpj(document)):
                filters.append(UserModel.cpf_cnpj == document)
            if not filters:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Informe um e-mail, CPF ou CNPJ válido.",
                )
            user = (
                self.db.query(UserModel)
                .filter(or_(*filters), UserModel.is_active.is_(True))
                .first()
            )
        else:
            if "@" in normalized_identifier:
                user = (
                    self.db.query(UserModel)
                    .filter(func.lower(UserModel.email) == normalized_identifier, UserModel.is_active.is_(True))
                    .first()
                )
            else:
                user = (
                    self.db.query(UserModel)
                    .filter(UserModel.credential_number == identifier, UserModel.is_active.is_(True))
                    .first()
                )
        password_ok = bool(user and verify_password(senha, user.senha_hash))
        if user and access_type == "cidadao" and not password_ok:
            password_ok = verify_password(self._only_digits(senha), user.senha_hash)
        if not user or not password_ok:
            self._invalid_credentials()
        if access_type == "cidadao" and user.role.slug != "cidadao":
            self._invalid_credentials()
        if access_type == "servidor" and user.role.slug in {"cidadao", "admin"}:
            self._invalid_credentials()
        if access_type == "admin" and user.role.slug != "admin":
            self._invalid_credentials()
        if access_type == "interno" and user.role.slug == "cidadao":
            self._invalid_credentials()

        methods = self._available_mfa_methods(user)
        if not methods:
            token = self._create_session_token(user, client_type)
            return LoginStartResponse(
                mfa_required=False,
                access_token=token.access_token,
                expires_at=token.expires_at,
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
        email = (email or '').strip().lower()
        existing_user = self.db.query(UserModel).filter(func.lower(UserModel.email) == email).first()
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
        email = (payload.email or "").strip().lower() or None
        if email and "@" not in email:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="E-mail inválido")
        if role_slug == "cidadao":
            document = self._validate_document(payload.cpf_cnpj, payload.tipo_pessoa)
            self._validate_citizen_registration_files(payload)
            self._validate_citizen_stay(payload)
            existing = (
                self.db.query(UserModel)
                .filter(UserModel.cpf_cnpj == document)
                .first()
            )
            if existing:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="CPF/CNPJ já cadastrado")
            if email and self.db.query(UserModel).filter(func.lower(UserModel.email) == email).first():
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="E-mail já cadastrado")
        elif not email:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="E-mail é obrigatório para usuários internos.",
            )
        else:
            document = None
            existing = self.db.query(UserModel).filter(func.lower(UserModel.email) == email).first()
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

        managed_inn_id = None
        tourism_categories = {"pousada_hotel", "restaurante", "quiosque"}
        if role_slug == "cidadao" and payload.business_category in tourism_categories:
            category_label = {
                "pousada_hotel": "pousada ou hotel",
                "restaurante": "restaurante",
                "quiosque": "quiosque",
            }.get(payload.business_category, "estabelecimento")
            inn_name = (payload.managed_inn_name or payload.razao_social or payload.nome or "").strip()
            if len(inn_name) < 2:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Informe o nome do {category_label}.")
            if payload.orla_access_requested:
                if not payload.endereco_latitude or not payload.endereco_longitude:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="Busque e selecione o endereço do estabelecimento para validar a geolocalização da Orla.",
                    )
                if not is_inside_orla(payload.endereco_latitude, payload.endereco_longitude):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="O endereço informado não está dentro da área demarcada da Orla. A gestão pode validar manualmente quando necessário.",
                    )
            inn = self.db.query(OrlaInn).filter(OrlaInn.name == inn_name).first()
            if not inn:
                beachfront = bool(is_inside_orla(payload.endereco_latitude, payload.endereco_longitude))
                inn = OrlaInn(
                    name=inn_name,
                    address=payload.endereco,
                    cep=payload.cep,
                    latitude=payload.endereco_latitude,
                    longitude=payload.endereco_longitude,
                    capacity=payload.managed_inn_capacity,
                    guest_capacity=payload.managed_inn_guest_capacity,
                    beachfront=beachfront,
                    approval_status="pending" if beachfront else "approved",
                )
                self.db.add(inn)
                self.db.flush()
            elif payload.managed_inn_capacity and not inn.capacity:
                inn.capacity = payload.managed_inn_capacity
            if payload.managed_inn_guest_capacity and not inn.guest_capacity:
                inn.guest_capacity = payload.managed_inn_guest_capacity
            if payload.endereco_latitude and payload.endereco_longitude and (not inn.latitude or not inn.longitude):
                inn.latitude = payload.endereco_latitude
                inn.longitude = payload.endereco_longitude
            managed_inn_id = inn.id

        user = UserModel(
            tipo_pessoa=payload.tipo_pessoa,
            nome=payload.nome,
            sobrenome=payload.sobrenome,
            razao_social=payload.razao_social,
            cpf_cnpj=document,
            credential_number=self._generate_credential_number(role_slug, secretaria_slug),
            email=email,
            senha_hash=hash_password(payload.senha),
            telefone=payload.telefone,
            endereco=payload.endereco,
            cep=payload.cep,
            endereco_latitude=payload.endereco_latitude,
            endereco_longitude=payload.endereco_longitude,
            tipo_usuario=payload.tipo_usuario,
            business_category=payload.business_category,
            managed_inn_id=managed_inn_id,
            tipo_estadia=payload.tipo_estadia if payload.tipo_usuario == "turista" else None,
            estadia_endereco=payload.estadia_endereco if payload.tipo_usuario == "turista" else None,
            estadia_cep=payload.estadia_cep if payload.tipo_usuario == "turista" else None,
            estadia_latitude=payload.estadia_latitude if payload.tipo_usuario == "turista" else None,
            estadia_longitude=payload.estadia_longitude if payload.tipo_usuario == "turista" else None,
            estadia_inicio=payload.estadia_inicio if payload.tipo_usuario == "turista" else None,
            estadia_fim=payload.estadia_fim if payload.tipo_usuario == "turista" else None,
            pousada_id=payload.pousada_id if payload.tipo_usuario == "turista" and payload.tipo_estadia == "pousada" else None,
            orla_access_requested=bool(payload.orla_access_requested),
            orla_access_status="solicitado" if payload.orla_access_requested else "nao_solicitado",
            foto_usuario_nome=payload.foto_usuario_nome,
            foto_usuario_url=payload.foto_usuario_url,
            documento_identificacao_nome=payload.documento_identificacao_nome,
            documento_identificacao_url=payload.documento_identificacao_url,
            documento_identificacao_tipo=payload.documento_identificacao_tipo,
            comprovante_residencia_nome=payload.comprovante_residencia_nome,
            comprovante_residencia_url=payload.comprovante_residencia_url,
            comprovante_residencia_tipo=payload.comprovante_residencia_tipo,
            comprovante_residencia_status=self._residence_proof_status(payload),
            comprovante_residencia_observacao=self._residence_proof_observation(payload),
            alvara_funcionamento_nome=payload.alvara_funcionamento_nome,
            alvara_funcionamento_url=payload.alvara_funcionamento_url,
            role_id=role.id,
            secretaria_id=secretaria.id if secretaria else None,
            mfa_email_enabled=bool(payload.mfa_email_enabled and email),
        )
        self.db.add(user)
        self.db.flush()
        if payload.orla_vehicle and role_slug == "cidadao" and payload.tipo_usuario == "turista":
            vehicle = payload.orla_vehicle
            plate_value = re.sub(r"[\s-]", "", vehicle.plate).upper()
            if not re.fullmatch(r"[A-Z]{3}[0-9][A-Z0-9][0-9]{2}", plate_value):
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Informe uma placa brasileira válida.")
            if self.db.query(OrlaVehicle).filter(OrlaVehicle.plate == plate_value).first():
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Placa já cadastrada.")
            self.db.add(OrlaVehicle(
                user_id=user.id,
                plate=plate_value,
                brand=vehicle.brand.strip(),
                model=vehicle.model.strip(),
                color=vehicle.color.strip(),
                establishment_name=(vehicle.establishment_name or "").strip() or None,
                is_excursion=bool(vehicle.is_excursion),
                driver_name=(vehicle.driver_name or "").strip() or None,
                driver_document=(vehicle.driver_document or "").strip() or None,
                driver_phone=(vehicle.driver_phone or "").strip() or None,
                passengers_count=vehicle.passengers_count,
                qr_token=secrets.token_urlsafe(32),
            ))
        if payload.mfa_email_enabled is not None:
            if payload.mfa_email_enabled and not user.email:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Informe um e-mail antes de ativar MFA por e-mail.",
                )
            user.mfa_email_enabled = bool(payload.mfa_email_enabled)
        self.db.commit()
        self.db.refresh(user)
        if user.email:
            subject, text, html = render_configured_email_template(
                self.db, 'welcome', {'nome': user.nome},
            )
            send_email(user.email, subject, text, html)
        return self.to_response(user)

    @staticmethod
    def _create_session_token(user: UserModel, client_type: str = "web") -> TokenResponse:
        session = AuthService._to_session(user)
        expires_delta = timedelta(days=1) if client_type == "app" else timedelta(hours=1)
        expires_at = datetime.now(timezone.utc) + expires_delta
        token = create_access_token(
            subject=str(user.id),
            claims={
                "role": session.role,
                "secretaria": session.secretaria,
                "client_type": client_type,
            },
            expires_delta=expires_delta,
        )
        return TokenResponse(access_token=token, expires_at=expires_at.isoformat(), user=session)

    def update_current_user(self, user: UserModel, payload: UserSelfUpdateRequest) -> UserResponse:
        for field in [
            "nome",
            "sobrenome",
            "telefone",
            "endereco",
            "foto_usuario_nome",
            "foto_usuario_url",
        ]:
            value = getattr(payload, field)
            if value is not None:
                setattr(user, field, value)
        if payload.mfa_email_enabled is not None:
            if payload.mfa_email_enabled and not user.email:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Informe um e-mail antes de ativar MFA por e-mail.",
                )
            user.mfa_email_enabled = bool(payload.mfa_email_enabled)
        self.db.commit()
        self.db.refresh(user)
        return self.to_response(user)

    def change_password(self, user: UserModel, payload: ChangePasswordRequest) -> TokenResponse:
        if not verify_password(payload.current_password, user.senha_hash):
            self._invalid_credentials()
        if payload.current_password == payload.new_password:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A nova senha deve ser diferente da senha atual.",
            )
        user.senha_hash = hash_password(payload.new_password)
        user.must_change_password = False
        self.db.commit()
        self.db.refresh(user)
        return self._create_session_token(user, "web")

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
            foto_usuario_url=user.foto_usuario_url,
            must_change_password=bool(user.must_change_password),
            business_category=user.business_category,
            managed_inn_id=user.managed_inn_id,
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
        if payload.tipo_pessoa == "PJ":
            if payload.tipo_usuario == "turista":
                return
            if not (payload.alvara_funcionamento_nome or payload.alvara_funcionamento_url):
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Anexe o alvará de funcionamento da pessoa jurídica para concluir o cadastro.",
                )
            return
        if payload.tipo_usuario != "morador":
            return
        if not (payload.foto_usuario_nome or payload.foto_usuario_url):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Inclua uma foto do usuário para concluir o cadastro.",
            )
        if not (payload.documento_identificacao_nome or payload.documento_identificacao_url):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Inclua RG ou CNH para concluir o cadastro.",
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

    def _validate_citizen_stay(self, payload: UserCreateRequest) -> None:
        if payload.tipo_usuario == "morador":
            return
        if not payload.tipo_estadia:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Informe o tipo de estadia do turista.")
        if not payload.estadia_inicio or not payload.estadia_fim:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Informe o período da estadia.")
        start_date = self._parse_date(payload.estadia_inicio, "Data inicial da estadia inválida.")
        end_date = self._parse_date(payload.estadia_fim, "Data final da estadia inválida.")
        if end_date < start_date:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="A data final da estadia deve ser igual ou posterior à data inicial.")
        if payload.tipo_estadia == "casa_aluguel" and not payload.estadia_endereco:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Informe o endereço da casa de aluguel.")
        if payload.tipo_estadia == "pousada":
            if payload.pousada_id:
                inn = self.db.get(OrlaInn, payload.pousada_id)
                if not inn:
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pousada não encontrada.")
            elif not payload.estadia_endereco:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Selecione a pousada ou informe nome e telefone da hospedagem.")

    @staticmethod
    def _residence_proof_status(payload: UserCreateRequest) -> str:
        if payload.tipo_pessoa == "PJ":
            return "nao_exigido"
        if payload.tipo_usuario != "morador":
            return "nao_exigido"
        name = (payload.comprovante_residencia_nome or "").lower()
        proof_type = (payload.comprovante_residencia_tipo or "").lower()
        if any(term in name for term in ["agua", "água", "embasa"]) or any(term in name for term in ["luz", "energia", "coelba", "neoenergia"]):
            return "pre_validado"
        if proof_type in {"agua", "luz"}:
            return "pendente_validacao"
        return "recusado"

    @staticmethod
    def _residence_proof_observation(payload: UserCreateRequest) -> str | None:
        if payload.tipo_pessoa == "PJ":
            return "Comprovante de residência não exigido para pessoa jurídica. Alvará anexado no cadastro."
        status_value = AuthService._residence_proof_status(payload)
        if status_value == "nao_exigido":
            return "Comprovante de residência não exigido para turista."
        if status_value == "pre_validado":
            return "Nome do arquivo indica conta de água/luz. A validação final depende da leitura do documento."
        if status_value == "pendente_validacao":
            return "Documento aceito para análise. Leitura automática do conteúdo será integrada na etapa de OCR."
        return "Tipo de comprovante não permitido."

    @staticmethod
    def _parse_date(value: str, message: str):
        try:
            return datetime.strptime(value, "%Y-%m-%d").date()
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=message) from exc

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
            cep=user.cep,
            tipo_usuario=user.tipo_usuario,
            business_category=user.business_category,
            managed_inn_id=user.managed_inn_id,
            tipo_estadia=user.tipo_estadia,
            estadia_endereco=user.estadia_endereco,
            estadia_cep=user.estadia_cep,
            estadia_inicio=user.estadia_inicio,
            estadia_fim=user.estadia_fim,
            orla_access_requested=bool(user.orla_access_requested),
            orla_access_status=user.orla_access_status,
            foto_usuario_url=user.foto_usuario_url,
            documento_identificacao_url=user.documento_identificacao_url,
            comprovante_residencia_url=user.comprovante_residencia_url,
            comprovante_residencia_status=user.comprovante_residencia_status,
            alvara_funcionamento_url=user.alvara_funcionamento_url,
            role=user.role.slug,
            secretaria=user.secretaria.slug if user.secretaria else None,
            permissions=AuthService._permission_slugs(user),
            must_change_password=bool(user.must_change_password),
            mfa_email_enabled=bool(user.mfa_email_enabled),
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

    def _generate_credential_number(self, role_slug: str, secretaria_slug: str | None) -> str | None:
        if role_slug == "cidadao":
            return None
        prefix = "ADM" if role_slug == "admin" else (secretaria_slug or "SRV").upper()[:6]
        for _ in range(10):
            value = f"{prefix}-{secrets.randbelow(900000) + 100000}"
            if not self.db.query(UserModel).filter(UserModel.credential_number == value).first():
                return value
        return f"{prefix}-{secrets.token_hex(4).upper()}"
