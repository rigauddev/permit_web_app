from datetime import date, datetime, timedelta
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from src.infra.database.models import (
    AttachmentModel,
    PermitRequestModel,
    PermitRequirementModel,
    SecretariaModel,
    UserModel,
)
from src.schemas.permit_schema import (
    AttachmentResponse,
    DamAttachmentRequest,
    PermitCreateRequest,
    PermitResponse,
    RequirementResponse,
)


QUESTION_RULES = {
    "tem_som": ("meio_ambiente", "Termo de Responsabilidade Ambiental"),
    "tem_palco": ("infraestrutura", "Vistoria de palco/estrutura"),
    "tem_gerador": ("infraestrutura", "Vistoria de gerador"),
    "tem_trio_eletrico": ("dmtran", "Vistoria de trio elétrico, CNH do motorista e mapa do circuito"),
    "bloqueia_via": ("dmtran", "Autorização para uso ou bloqueio de via pública"),
    "tem_alimentacao": ("vigilancia_sanitaria", "Vistoria de equipamentos e instalações de alimentação"),
    "precisa_guarda": ("guarda_civil", "Ofício solicitando presença da Guarda Civil Municipal"),
}


class PermitService:
    def __init__(self, db: Session):
        self.db = db

    def create_request(self, payload: PermitCreateRequest, solicitante: UserModel) -> PermitResponse:
        self._validate_payload(payload)
        protocolo = self._generate_protocol()
        dam_status = "isento" if payload.is_beneficente else "pendente_prefeitura"
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
        if role == "cidadao":
            query = query.filter(PermitRequestModel.solicitante_id == current_user.id)
        elif role == "operador_secretaria":
            query = (
                query.join(PermitRequirementModel)
                .filter(PermitRequirementModel.secretaria_id == current_user.secretaria_id)
                .distinct()
            )
        return [self.to_response(item) for item in query.order_by(PermitRequestModel.created_at.desc()).all()]

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

        attachment = AttachmentModel(
            permit_request_id=request.id,
            tipo_documento="dam",
            nome_arquivo=payload.nome_arquivo,
            arquivo_url=payload.arquivo_url,
            mime_type=payload.mime_type,
            tamanho_bytes=payload.tamanho_bytes,
        )
        request.dam_status = "anexado"
        self.db.add(attachment)
        self.db.commit()
        self.db.refresh(attachment)
        return self._attachment_to_response(attachment)

    @staticmethod
    def _build_requirements(respostas: dict[str, Any]) -> list[tuple[str, str]]:
        requirements: list[tuple[str, str]] = []
        seen = set()
        for answer_key, (secretaria_slug, tipo_exigencia) in QUESTION_RULES.items():
            if respostas.get(answer_key) is True and (secretaria_slug, tipo_exigencia) not in seen:
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

        if event_date < date.today() + timedelta(days=15):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A solicitação precisa ter pelo menos 15 dias de antecedência.",
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
        if role in {"gestor_secretaria", "operador_secretaria"} and secretaria == "receita_municipal":
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente para anexar DAM")

    @staticmethod
    def _generate_protocol() -> str:
        return f"ALV-{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')}"

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
                RequirementResponse(
                    id=item.id,
                    secretaria=item.secretaria.slug,
                    tipo_exigencia=item.tipo_exigencia,
                    status=item.status,
                    observacoes=item.observacoes,
                )
                for item in request.requirements
            ],
            attachments=[PermitService._attachment_to_response(item) for item in request.attachments],
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
