import os
import secrets
import smtplib
from email.message import EmailMessage
from datetime import date, datetime, time, timedelta, timezone
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.core.security import create_event_credential_token, decode_token, hash_token, verify_token_hash
from src.infra.database.models import (
    AttachmentModel,
    AuthorizationTemplateModel,
    EventCredentialModel,
    PermitCommentModel,
    PermitRequestModel,
    PermitRequirementModel,
    SecretariaModel,
    UserModel,
)
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
    PermitCreateRequest,
    PermitResponse,
    RequirementResponse,
    RequirementStatusUpdateRequest,
)


QUESTION_RULES = {
    "tem_som": [("meio_ambiente", "Termo de Responsabilidade Ambiental")],
    "local_fixo_sem_alvara": [
        ("desenvolvimento_economico", "Regularização do alvará de funcionamento do local fixo")
    ],
    "precisa_avcb": [("infraestrutura", "Auto de Vistoria do Corpo de Bombeiros (AVCB)")],
    "tem_palco": [
        ("infraestrutura", "Vistoria de palco/estrutura"),
        ("infraestrutura", "Anotação de Responsabilidade Técnica (ART) da estrutura"),
    ],
    "tem_gerador": [
        ("infraestrutura", "Vistoria de gerador"),
        ("infraestrutura", "Anotação de Responsabilidade Técnica (ART) do gerador"),
    ],
    "precisa_planta_baixa": [
        ("infraestrutura", "Planta baixa para evento particular de médio ou grande porte em local fixo")
    ],
    "tem_trio_eletrico": [("dmtran", "Vistoria de trio elétrico, CNH do motorista e mapa do circuito")],
    "bloqueia_via": [
        ("dmtran", "Autorização para uso ou bloqueio de via pública"),
        ("dmtran", "Croqui/mapa do circuito ou desvio de trânsito"),
    ],
    "tem_alimentacao": [("vigilancia_sanitaria", "Vistoria de equipamentos e instalações de alimentação")],
    "precisa_ambulancia": [("vigilancia_sanitaria", "Ofício solicitando ambulância no local do evento")],
    "precisa_guarda": [("guarda_civil", "Ofício solicitando presença da Guarda Civil Municipal")],
}

REQUIREMENT_STATUSES = {"aguardando_analise", "aprovada", "recusada", "pendente_documento"}
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://localhost:8080")
SDE_EMAIL = os.getenv("SDE_EMAIL", "sde@valenca.ba.gov.br")
STATUS_AGUARDANDO_GERACAO_DAM = "aguardando_geracao_dam"
STATUS_AGUARDANDO_PAGAMENTO_DAM = "aguardando_pagamento_dam"
STATUS_AGUARDANDO_GERACAO_ALVARA = "aguardando_geracao_alvara"
STATUS_AUTORIZADA = "autorizada"
DAM_STATUS_PENDENTE_PREFEITURA = "pendente_prefeitura"
DAM_STATUS_GERADO = "gerado"
DAM_STATUS_PAGO = "pago"
DAM_STATUS_ISENTO = "isento"
ATTACHMENT_DAM = "dam"
ATTACHMENT_DAM_PAYMENT = "comprovante_pagamento_dam"
ATTACHMENT_FINAL_PERMIT = "alvara_evento"
AUTHORIZATION_TEMPLATE_SLUG = "alvara_evento"
DEFAULT_AUTHORIZATION_HEADER = (
    "A Prefeitura Municipal de Valença, por meio da Central de Eventos, autoriza a realização do evento abaixo "
    "após as anuências dos órgãos competentes e a regularização do DAM ou isenção aplicável."
)
DEFAULT_AUTHORIZATION_FOOTER = (
    "Documento mantido no sistema municipal. A validade deve ser confirmada pela leitura do QR Code. "
    "Quando houver exigência de assinatura, o responsável pode imprimir, assinar e anexar, ou assinar "
    "eletronicamente pelo aplicativo gov.br e anexar o arquivo assinado."
)


class PermitService:
    def __init__(self, db: Session):
        self.db = db

    def create_request(self, payload: PermitCreateRequest, solicitante: UserModel) -> PermitResponse:
        self._validate_payload(payload)
        protocolo = self._generate_protocol()
        dam_status = DAM_STATUS_ISENTO if payload.is_beneficente else "nao_gerado"
        request = PermitRequestModel(
            protocolo=protocolo,
            solicitante_id=solicitante.id,
            status="enviada",
            dam_status=dam_status,
            is_beneficente=payload.is_beneficente,
            instituicao_beneficiada=payload.instituicao_beneficiada,
            dados_responsavel=payload.dados_responsavel,
            dados_evento=payload.dados_evento,
            respostas=payload.respostas,
        )
        self.db.add(request)
        self.db.flush()

        for secretaria_slug, tipo_exigencia in self._build_requirements(payload.respostas):
            secretaria = self.db.query(SecretariaModel).filter(SecretariaModel.slug == secretaria_slug).first()
            if secretaria:
                self.db.add(
                    PermitRequirementModel(
                        permit_request_id=request.id,
                        secretaria_id=secretaria.id,
                        tipo_exigencia=tipo_exigencia,
                    )
                )

        if payload.is_beneficente:
            receita = self.db.query(SecretariaModel).filter(SecretariaModel.slug == "receita_municipal").first()
            if receita:
                self.db.add(
                    PermitRequirementModel(
                        permit_request_id=request.id,
                        secretaria_id=receita.id,
                        tipo_exigencia="Conferência de declaração de evento beneficente",
                    )
                )

        self.db.commit()
        self.db.refresh(request)
        return self.to_response(request)

    def list_requests(self, current_user: UserModel) -> list[PermitResponse]:
        query = self.db.query(PermitRequestModel)
        role = current_user.role.slug
        secretaria = current_user.secretaria.slug if current_user.secretaria else None
        if role == "cidadao":
            query = query.filter(PermitRequestModel.solicitante_id == current_user.id)
        elif role in {"gestor_secretaria", "operador_secretaria"} and secretaria != "desenvolvimento_economico":
            query = (
                query.join(PermitRequirementModel)
                .filter(PermitRequirementModel.secretaria_id == current_user.secretaria_id)
                .distinct()
            )
        return [self.to_response(item) for item in query.order_by(PermitRequestModel.created_at.desc()).all()]

    def get_request(self, request_id: int, current_user: UserModel) -> PermitResponse:
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        if not self._can_view_request(request, current_user) and not self._can_issue_authorization(current_user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        return self.to_response(request)

    def update_requirement_status(
        self,
        requirement_id: int,
        payload: RequirementStatusUpdateRequest,
        current_user: UserModel,
    ) -> RequirementResponse:
        requirement = (
            self.db.query(PermitRequirementModel).filter(PermitRequirementModel.id == requirement_id).first()
        )
        if not requirement:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exigência não encontrada")
        self._ensure_can_manage_requirement(requirement, current_user)

        new_status = payload.status.strip()
        if new_status not in REQUIREMENT_STATUSES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Status de exigência inválido")

        permit_request = requirement.permit_request
        previous_status = permit_request.status

        requirement.status = new_status
        if payload.observacoes is not None:
            requirement.observacoes = payload.observacoes
            if payload.observacoes.strip():
                self._add_comment(
                    requirement.permit_request_id,
                    current_user,
                    payload.observacoes.strip(),
                    requirement_id=requirement.id,
                )

        self._recalculate_request_status(permit_request)
        if (
            previous_status != STATUS_AGUARDANDO_GERACAO_DAM
            and permit_request.status == STATUS_AGUARDANDO_GERACAO_DAM
        ):
            self._notify_development_economico_ready_for_dam(permit_request, current_user)
        self.db.commit()
        self.db.refresh(requirement)
        return self._requirement_to_response(requirement)

    def create_comment(
        self,
        request_id: int,
        payload: CommentCreateRequest,
        current_user: UserModel,
    ) -> CommentResponse:
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        if not self._can_view_request(request, current_user) and not self._can_issue_authorization(current_user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")

        requirement = None
        if payload.requirement_id is not None:
            requirement = (
                self.db.query(PermitRequirementModel)
                .filter(
                    PermitRequirementModel.id == payload.requirement_id,
                    PermitRequirementModel.permit_request_id == request.id,
                )
                .first()
            )
            if not requirement:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exigência não encontrada")
            if current_user.role.slug != "cidadao":
                self._ensure_can_manage_requirement(requirement, current_user)

        comment = self._add_comment(
            request.id,
            current_user,
            payload.mensagem.strip(),
            requirement_id=requirement.id if requirement else None,
        )
        self.db.commit()
        self.db.refresh(comment)
        return self._comment_to_response(comment)

    def attach_dam(
        self,
        request_id: int,
        payload: DamAttachmentRequest,
        current_user: UserModel,
    ) -> AttachmentResponse:
        self._ensure_can_attach_dam(current_user)
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        if request.is_beneficente:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Evento beneficente é isento de DAM.",
            )
        self._recalculate_request_status(request)
        if request.status != STATUS_AGUARDANDO_GERACAO_DAM:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="DAM só pode ser anexado após todas as anuências serem aprovadas.",
            )

        attachment = self._create_attachment(request, payload, ATTACHMENT_DAM)
        request.dam_status = DAM_STATUS_GERADO
        request.status = STATUS_AGUARDANDO_PAGAMENTO_DAM
        self._notify_citizen_dam_ready(request, current_user)
        self.db.add(attachment)
        self.db.commit()
        self.db.refresh(attachment)
        return self._attachment_to_response(attachment)

    def attach_dam_payment_proof(
        self,
        request_id: int,
        payload: AttachmentCreateRequest,
        current_user: UserModel,
    ) -> AttachmentResponse:
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        if request.solicitante_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        self._recalculate_request_status(request)
        if request.status != STATUS_AGUARDANDO_PAGAMENTO_DAM:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Comprovante só pode ser anexado quando o DAM estiver aguardando pagamento.",
            )

        attachment = self._create_attachment(request, payload, ATTACHMENT_DAM_PAYMENT)
        request.dam_status = DAM_STATUS_PAGO
        request.status = STATUS_AGUARDANDO_GERACAO_ALVARA
        self._notify_development_economico_ready_for_final_permit(request, current_user)
        self.db.add(attachment)
        self.db.commit()
        self.db.refresh(attachment)
        return self._attachment_to_response(attachment)

    def attach_final_permit(
        self,
        request_id: int,
        payload: AttachmentCreateRequest,
        current_user: UserModel,
    ) -> EventCredentialResponse:
        self._ensure_can_finalize_permit(current_user)
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        self._recalculate_request_status(request)
        if request.status not in {STATUS_AGUARDANDO_GERACAO_ALVARA, "isenta_dam"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Alvará só pode ser anexado após pagamento do DAM ou isenção validada.",
            )
        attachment = self._create_attachment(request, payload, ATTACHMENT_FINAL_PERMIT)
        request.status = STATUS_AUTORIZADA if not request.is_beneficente else "isenta_dam"
        self.db.add(attachment)
        self.db.commit()
        self.db.refresh(attachment)
        self._notify_citizen_final_permit_ready(request, current_user)
        return self.issue_authorization(request.id, current_user)

    def issue_authorization(self, request_id: int, current_user: UserModel) -> EventCredentialResponse:
        self._ensure_can_issue_authorization(current_user)
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        self._recalculate_request_status(request)
        if request.status != "autorizada" and request.status != "isenta_dam":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Solicitação ainda não está apta para emissão da autorização.",
            )

        active_credential = next((item for item in request.credentials if item.status == "ativa"), None)
        if active_credential:
            token = create_event_credential_token(active_credential.codigo_publico, request.id)
            active_credential.token_hash = hash_token(token)
            self.db.commit()
            self.db.refresh(active_credential)
            return self._credential_to_response(active_credential, token=token)

        codigo_publico = self._generate_public_code()
        token = create_event_credential_token(codigo_publico, request.id)
        valid_from, valid_until = self._credential_validity(request)
        credential = EventCredentialModel(
            permit_request_id=request.id,
            codigo_publico=codigo_publico,
            token_hash=hash_token(token),
            status="ativa",
            valid_from=valid_from,
            valid_until=valid_until,
            issued_by=current_user.id,
        )
        self.db.add(credential)
        self.db.commit()
        self.db.refresh(credential)
        credential.raw_token = token
        return self._credential_to_response(credential, token=token)

    def get_authorization(self, request_id: int, current_user: UserModel) -> EventCredentialResponse:
        request = self.db.query(PermitRequestModel).filter(PermitRequestModel.id == request_id).first()
        if not request:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitação não encontrada")
        if not self._can_view_request(request, current_user) and not self._can_issue_authorization(current_user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        credential = next((item for item in request.credentials if item.status == "ativa"), None)
        if not credential:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Credencial ativa não encontrada")
        token = create_event_credential_token(credential.codigo_publico, request.id)
        if not verify_token_hash(token, credential.token_hash):
            credential.token_hash = hash_token(token)
            self.db.commit()
            self.db.refresh(credential)
        return self._credential_to_response(credential, token=token)

    def validate_event_credential(self, codigo_publico: str, token: str) -> EventCredentialValidationResponse:
        credential = (
            self.db.query(EventCredentialModel)
            .filter(EventCredentialModel.codigo_publico == codigo_publico)
            .first()
        )
        if not credential:
            return EventCredentialValidationResponse(valid=False, reason="Credencial não encontrada")
        if not self._validate_credential_token(credential, token):
            return EventCredentialValidationResponse(valid=False, reason="Token inválido")
        now = datetime.now(timezone.utc)
        valid_from = self._as_aware(credential.valid_from)
        valid_until = self._as_aware(credential.valid_until)
        if credential.status != "ativa":
            return EventCredentialValidationResponse(
                valid=False,
                reason="Credencial não está ativa",
                credential_status=credential.status,
            )
        if valid_from > now:
            return EventCredentialValidationResponse(
                valid=False,
                reason="Credencial ainda não está vigente",
                credential_status=credential.status,
            )
        if valid_until < now:
            credential.status = "expirada"
            self.db.commit()
            return EventCredentialValidationResponse(
                valid=False,
                reason="Credencial expirada",
                credential_status="expirada",
            )

        request = credential.permit_request
        self._recalculate_request_status(request)
        if request.status not in {"autorizada", "isenta_dam"}:
            return EventCredentialValidationResponse(
                valid=False,
                reason="Solicitação não está autorizada",
                credential_status=credential.status,
                status_solicitacao=request.status,
            )

        evento = request.dados_evento or {}
        responsavel = request.dados_responsavel or {}
        dam_attachment = next((item for item in request.attachments if item.tipo_documento == "dam"), None)
        return EventCredentialValidationResponse(
            valid=True,
            credential_status=credential.status,
            protocolo=request.protocolo,
            nome_evento=str(evento.get("nome_evento", "")),
            data_evento=str(evento.get("data_evento", "")),
            horario_inicio=str(evento.get("horario_inicio", "")),
            horario_termino=str(evento.get("horario_termino", "")),
            local_evento=str(evento.get("endereco_evento", "")),
            responsavel=str(responsavel.get("nome", "")),
            publico_estimado=str(evento.get("publico_estimado", "")),
            status_solicitacao=request.status,
            dam_status=request.dam_status,
            requirements=[self._requirement_to_response(item) for item in request.requirements],
            dam_attachment=self._attachment_to_response(dam_attachment) if dam_attachment else None,
        )

    def revoke_event_credential(
        self,
        credential_id: int,
        payload: EventCredentialRevokeRequest,
        current_user: UserModel,
    ) -> EventCredentialResponse:
        self._ensure_can_issue_authorization(current_user)
        credential = self.db.query(EventCredentialModel).filter(EventCredentialModel.id == credential_id).first()
        if not credential:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Credencial não encontrada")
        credential.status = "revogada"
        credential.revoked_at = datetime.now(timezone.utc)
        credential.revoked_by = current_user.id
        credential.revocation_reason = payload.reason
        self.db.commit()
        self.db.refresh(credential)
        return self._credential_to_response(credential)

    def get_authorization_template(self) -> AuthorizationTemplateResponse:
        template = self._get_or_create_authorization_template()
        return self._template_to_response(template)

    def update_authorization_template(
        self,
        payload: AuthorizationTemplateRequest,
        current_user: UserModel,
    ) -> AuthorizationTemplateResponse:
        if current_user.role.slug not in {"admin", "gestor_secretaria"}:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        template = self._get_or_create_authorization_template()
        template.header_text = payload.header_text
        template.footer_text = payload.footer_text
        template.updated_by = current_user.id
        self.db.commit()
        self.db.refresh(template)
        return self._template_to_response(template)

    @staticmethod
    def _build_requirements(respostas: dict[str, Any]) -> list[tuple[str, str]]:
        requirements: list[tuple[str, str]] = []
        seen = set()
        for answer_key, rules in QUESTION_RULES.items():
            if respostas.get(answer_key) is True:
                for secretaria_slug, tipo_exigencia in rules:
                    if (secretaria_slug, tipo_exigencia) not in seen:
                        requirements.append((secretaria_slug, tipo_exigencia))
                        seen.add((secretaria_slug, tipo_exigencia))
        return requirements

    @staticmethod
    def _validate_payload(payload: PermitCreateRequest) -> None:
        responsible_required = ["nome", "cpf_cnpj", "telefone", "email", "endereco"]
        event_required = [
            "nome_evento",
            "data_evento",
            "endereco_evento",
            "publico_estimado",
            "horario_inicio",
            "horario_termino",
        ]

        if any(not str(payload.dados_responsavel.get(field, "")).strip() for field in responsible_required):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Dados obrigatórios do responsável não foram preenchidos.",
            )

        if any(not str(payload.dados_evento.get(field, "")).strip() for field in event_required):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Dados obrigatórios do evento não foram preenchidos.",
            )

        try:
            event_date = date.fromisoformat(str(payload.dados_evento["data_evento"]))
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Data do evento deve estar no formato AAAA-MM-DD.",
            ) from exc

        if event_date < PermitService._add_business_days(date.today(), 15):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A solicitação precisa ter pelo menos 15 dias úteis de antecedência.",
            )

        attachment_names = payload.dados_evento.get("anexos_informados") or []
        if not isinstance(attachment_names, list) or len(attachment_names) < 3:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Informe RG/CPF, comprovante de residência e alvará do local.",
            )

        if payload.is_beneficente and not (payload.instituicao_beneficiada or "").strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Informe a instituição beneficiada pelo evento beneficente.",
            )

    @staticmethod
    def _ensure_can_attach_dam(current_user: UserModel) -> None:
        role = current_user.role.slug
        secretaria = current_user.secretaria.slug if current_user.secretaria else None
        if role == "admin":
            return
        if role in {"gestor_secretaria", "operador_secretaria"} and secretaria == "desenvolvimento_economico":
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente para anexar DAM")

    @staticmethod
    def _ensure_can_finalize_permit(current_user: UserModel) -> None:
        role = current_user.role.slug
        secretaria = current_user.secretaria.slug if current_user.secretaria else None
        if role == "admin":
            return
        if role in {"gestor_secretaria", "operador_secretaria"} and secretaria == "desenvolvimento_economico":
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente para finalizar alvará")

    @staticmethod
    def _ensure_can_issue_authorization(current_user: UserModel) -> None:
        if PermitService._can_issue_authorization(current_user):
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente para emitir autorização")

    @staticmethod
    def _can_issue_authorization(current_user: UserModel) -> bool:
        role = current_user.role.slug
        secretaria = current_user.secretaria.slug if current_user.secretaria else None
        if role == "admin":
            return True
        if role in {"gestor_secretaria", "operador_secretaria"} and secretaria == "desenvolvimento_economico":
            return True
        return False

    @staticmethod
    def _can_view_request(request: PermitRequestModel, current_user: UserModel) -> bool:
        role = current_user.role.slug
        if role == "admin":
            return True
        if role == "cidadao":
            return request.solicitante_id == current_user.id
        if role in {"gestor_secretaria", "operador_secretaria"} and current_user.secretaria and current_user.secretaria.slug == "desenvolvimento_economico":
            return True
        if role in {"gestor_secretaria", "operador_secretaria"}:
            return any(item.secretaria_id == current_user.secretaria_id for item in request.requirements)
        return False

    @staticmethod
    def _ensure_can_manage_requirement(requirement: PermitRequirementModel, current_user: UserModel) -> None:
        role = current_user.role.slug
        if role == "admin":
            return
        if role in {"gestor_secretaria", "operador_secretaria"} and requirement.secretaria_id == current_user.secretaria_id:
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente para atuar nesta exigência")

    @staticmethod
    def _recalculate_request_status(request: PermitRequestModel) -> None:
        requirement_statuses = [item.status for item in request.requirements]
        attachment_types = {item.tipo_documento for item in request.attachments}
        if not requirement_statuses:
            request.status = "enviada"
            return
        if "recusada" in requirement_statuses:
            request.status = "indeferida"
            return
        if "pendente_documento" in requirement_statuses:
            request.status = "pendente_correcao"
            return
        if all(item == "aprovada" for item in requirement_statuses):
            if request.is_beneficente:
                request.dam_status = DAM_STATUS_ISENTO
                if ATTACHMENT_FINAL_PERMIT in attachment_types:
                    request.status = "isenta_dam"
                else:
                    request.status = STATUS_AGUARDANDO_GERACAO_ALVARA
            elif ATTACHMENT_FINAL_PERMIT in attachment_types:
                request.dam_status = DAM_STATUS_PAGO
                request.status = STATUS_AUTORIZADA
            elif ATTACHMENT_DAM_PAYMENT in attachment_types or request.dam_status == DAM_STATUS_PAGO:
                request.dam_status = DAM_STATUS_PAGO
                request.status = STATUS_AGUARDANDO_GERACAO_ALVARA
            elif ATTACHMENT_DAM in attachment_types or request.dam_status == DAM_STATUS_GERADO:
                request.dam_status = DAM_STATUS_GERADO
                request.status = STATUS_AGUARDANDO_PAGAMENTO_DAM
            else:
                request.dam_status = DAM_STATUS_PENDENTE_PREFEITURA
                request.status = STATUS_AGUARDANDO_GERACAO_DAM
            return
        request.status = "em_analise"

    def _add_comment(
        self,
        request_id: int,
        author: UserModel,
        mensagem: str,
        requirement_id: int | None = None,
    ) -> PermitCommentModel:
        comment = PermitCommentModel(
            permit_request_id=request_id,
            requirement_id=requirement_id,
            author_id=author.id,
            mensagem=mensagem,
        )
        self.db.add(comment)
        return comment

    @staticmethod
    def _create_attachment(
        request: PermitRequestModel,
        payload: AttachmentCreateRequest,
        tipo_documento: str,
    ) -> AttachmentModel:
        return AttachmentModel(
            permit_request_id=request.id,
            tipo_documento=tipo_documento,
            nome_arquivo=payload.nome_arquivo,
            arquivo_url=payload.arquivo_url,
            mime_type=payload.mime_type,
            tamanho_bytes=payload.tamanho_bytes,
        )

    def _notify_development_economico_ready_for_dam(
        self,
        request: PermitRequestModel,
        actor: UserModel,
    ) -> None:
        self._record_email_notification(
            request,
            actor,
            destinatario=SDE_EMAIL,
            assunto="Solicitação pronta para geração do DAM",
            link=f"{PUBLIC_BASE_URL}/secretaria-requests?status={STATUS_AGUARDANDO_GERACAO_DAM}",
            mensagem=(
                "Todas as exigências da solicitação foram aprovadas. "
                "A solicitação está aguardando geração/anexo do DAM."
            ),
        )

    def _notify_citizen_dam_ready(self, request: PermitRequestModel, actor: UserModel) -> None:
        self._record_email_notification(
            request,
            actor,
            destinatario=str((request.dados_responsavel or {}).get("email") or request.solicitante.email),
            assunto="DAM disponível para pagamento",
            link=f"{PUBLIC_BASE_URL}/my-requests?status={STATUS_AGUARDANDO_PAGAMENTO_DAM}",
            mensagem=(
                "O DAM foi anexado pela Secretaria de Desenvolvimento Econômico. "
                "O solicitante deve realizar o pagamento e anexar o comprovante no sistema."
            ),
        )

    def _notify_development_economico_ready_for_final_permit(
        self,
        request: PermitRequestModel,
        actor: UserModel,
    ) -> None:
        self._record_email_notification(
            request,
            actor,
            destinatario=SDE_EMAIL,
            assunto="Comprovante do DAM anexado - gerar alvará",
            link=(
                f"{PUBLIC_BASE_URL}/secretaria-requests?"
                f"status={STATUS_AGUARDANDO_GERACAO_DAM},{STATUS_AGUARDANDO_GERACAO_ALVARA}"
            ),
            mensagem=(
                "O solicitante anexou o comprovante de pagamento do DAM. "
                "A solicitação está aguardando geração/anexo do alvará."
            ),
        )

    def _notify_citizen_final_permit_ready(self, request: PermitRequestModel, actor: UserModel) -> None:
        self._record_email_notification(
            request,
            actor,
            destinatario=str((request.dados_responsavel or {}).get("email") or request.solicitante.email),
            assunto="Alvará de evento emitido",
            link=f"{PUBLIC_BASE_URL}/my-requests?status={STATUS_AUTORIZADA}",
            mensagem=(
                "O alvará foi anexado e a credencial/QR Code de validação está disponível no sistema."
            ),
        )

    def _record_email_notification(
        self,
        request: PermitRequestModel,
        actor: UserModel,
        destinatario: str,
        assunto: str,
        link: str,
        mensagem: str,
    ) -> None:
        body = (
            f"[NOTIFICAÇÃO POR E-MAIL - MVP]\n"
            f"Destinatário: {destinatario}\n"
            f"Assunto: {assunto}\n"
            f"Link: {link}\n"
            f"Mensagem: {mensagem}"
        )
        email_status = self._send_email(destinatario, assunto, f"{mensagem}\n\nAcesse: {link}")
        if email_status:
            body = f"{body}\nStatus do envio: {email_status}"
        print(body)
        self._add_comment(request.id, actor, body)

    @staticmethod
    def _send_email(destinatario: str, assunto: str, mensagem: str) -> str:
        host = os.getenv("SMTP_HOST")
        if not host:
            return "SMTP não configurado; notificação registrada no processo."

        port = int(os.getenv("SMTP_PORT", "587"))
        smtp_from = os.getenv("SMTP_FROM") or os.getenv("SMTP_USER") or "no-reply@valenca.ba.gov.br"
        msg = EmailMessage()
        msg["From"] = smtp_from
        msg["To"] = destinatario
        msg["Subject"] = assunto
        msg.set_content(mensagem)

        try:
            with smtplib.SMTP(host, port, timeout=10) as smtp:
                if os.getenv("SMTP_USE_TLS", "true").lower() in {"1", "true", "yes"}:
                    smtp.starttls()
                user = os.getenv("SMTP_USER")
                password = os.getenv("SMTP_PASSWORD")
                if user and password:
                    smtp.login(user, password)
                smtp.send_message(msg)
            return "E-mail enviado via SMTP."
        except Exception as exc:  # pragma: no cover - depende do provedor SMTP externo.
            return f"Falha no SMTP; notificação registrada no processo. Erro: {exc}"

    @staticmethod
    def _generate_protocol() -> str:
        return f"ALV-{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')}"

    def _get_or_create_authorization_template(self) -> AuthorizationTemplateModel:
        template = (
            self.db.query(AuthorizationTemplateModel)
            .filter(AuthorizationTemplateModel.slug == AUTHORIZATION_TEMPLATE_SLUG)
            .first()
        )
        if template:
            return template
        template = AuthorizationTemplateModel(
            slug=AUTHORIZATION_TEMPLATE_SLUG,
            header_text=DEFAULT_AUTHORIZATION_HEADER,
            footer_text=DEFAULT_AUTHORIZATION_FOOTER,
        )
        self.db.add(template)
        self.db.commit()
        self.db.refresh(template)
        return template

    def _generate_public_code(self) -> str:
        for _ in range(10):
            code = f"EVT-{secrets.token_urlsafe(6).replace('_', '').replace('-', '').upper()[:8]}"
            existing = (
                self.db.query(EventCredentialModel)
                .filter(EventCredentialModel.codigo_publico == code)
                .first()
            )
            if not existing:
                return code
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Não foi possível gerar credencial")

    @staticmethod
    def _credential_validity(request: PermitRequestModel) -> tuple[datetime, datetime]:
        event_data = request.dados_evento or {}
        event_date = date.fromisoformat(str(event_data.get("data_evento")))
        end = PermitService._parse_time(str(event_data.get("horario_termino") or "23:59"))
        valid_from = datetime.now(timezone.utc)
        valid_until = datetime.combine(event_date, end).replace(tzinfo=timezone.utc) + timedelta(hours=12)
        if valid_until <= valid_from:
            valid_until = valid_from + timedelta(days=1)
        return valid_from, valid_until

    @staticmethod
    def _parse_time(value: str) -> time:
        try:
            hour, minute = value.split(":", maxsplit=1)
            return time(hour=int(hour), minute=int(minute[:2]))
        except (ValueError, TypeError):
            return time(hour=0, minute=0)

    @staticmethod
    def _validate_credential_token(credential: EventCredentialModel, token: str) -> bool:
        try:
            payload = decode_token(token)
        except ValueError:
            return False
        if payload.get("purpose") != "event_credential":
            return False
        if payload.get("sub") != credential.codigo_publico:
            return False
        if payload.get("permit_request_id") != credential.permit_request_id:
            return False
        return verify_token_hash(token, credential.token_hash)

    @staticmethod
    def _as_aware(value: datetime) -> datetime:
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)

    @staticmethod
    def _add_business_days(start_date: date, business_days: int) -> date:
        current_date = start_date
        added_days = 0
        while added_days < business_days:
            current_date += timedelta(days=1)
            if current_date.weekday() < 5:
                added_days += 1
        return current_date

    @staticmethod
    def to_response(request: PermitRequestModel) -> PermitResponse:
        return PermitResponse(
            id=request.id,
            protocolo=request.protocolo,
            tipo=request.tipo,
            status=request.status,
            dam_status=request.dam_status,
            is_beneficente=request.is_beneficente,
            dados_responsavel=request.dados_responsavel,
            dados_evento=request.dados_evento,
            respostas=request.respostas,
            created_at=request.created_at,
            requirements=[
                PermitService._requirement_to_response(item)
                for item in request.requirements
            ],
            attachments=[PermitService._attachment_to_response(item) for item in request.attachments],
            comments=[PermitService._comment_to_response(item) for item in request.comments],
            credentials=[PermitService._credential_to_response(item) for item in request.credentials],
        )

    @staticmethod
    def _requirement_to_response(requirement: PermitRequirementModel) -> RequirementResponse:
        return RequirementResponse(
            id=requirement.id,
            secretaria=requirement.secretaria.slug,
            tipo_exigencia=requirement.tipo_exigencia,
            status=requirement.status,
            observacoes=requirement.observacoes,
        )

    @staticmethod
    def _attachment_to_response(attachment: AttachmentModel) -> AttachmentResponse:
        return AttachmentResponse(
            id=attachment.id,
            tipo_documento=attachment.tipo_documento,
            nome_arquivo=attachment.nome_arquivo,
            arquivo_url=attachment.arquivo_url,
            mime_type=attachment.mime_type,
            tamanho_bytes=attachment.tamanho_bytes,
        )

    @staticmethod
    def _comment_to_response(comment: PermitCommentModel) -> CommentResponse:
        return CommentResponse(
            id=comment.id,
            permit_request_id=comment.permit_request_id,
            requirement_id=comment.requirement_id,
            author_id=comment.author_id,
            author_name=comment.author.nome,
            mensagem=comment.mensagem,
            created_at=comment.created_at,
        )

    @staticmethod
    def _credential_to_response(credential: EventCredentialModel, token: str | None = None) -> EventCredentialResponse:
        validation_url = f"{PUBLIC_BASE_URL}/validar-evento/{credential.codigo_publico}"
        if token:
            validation_url = f"{validation_url}?t={token}"
        return EventCredentialResponse(
            id=credential.id,
            permit_request_id=credential.permit_request_id,
            codigo_publico=credential.codigo_publico,
            status=credential.status,
            valid_from=credential.valid_from,
            valid_until=credential.valid_until,
            issued_at=credential.issued_at,
            validation_url=validation_url,
        )

    @staticmethod
    def _template_to_response(template: AuthorizationTemplateModel) -> AuthorizationTemplateResponse:
        return AuthorizationTemplateResponse(
            id=template.id,
            slug=template.slug,
            header_text=template.header_text,
            footer_text=template.footer_text,
            updated_at=template.updated_at,
        )
