from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from src.infra.database.models import PermitRequestModel, PermitRequirementModel, SecretariaModel, UserModel
from src.schemas.permit_schema import PermitCreateRequest, PermitResponse, RequirementResponse


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
        )
