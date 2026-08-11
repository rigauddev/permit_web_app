from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field


class PermitCreateRequest(BaseModel):
    is_beneficente: bool = False
    instituicao_beneficiada: str | None = None
    dados_responsavel: dict[str, Any]
    dados_evento: dict[str, Any]
    respostas: dict[str, Any] = Field(default_factory=dict)


class QuestionCreateRequest(BaseModel):
    key: str = Field(..., min_length=3, max_length=80, pattern="^[a-z0-9_]+$")
    pergunta: str = Field(..., min_length=3, max_length=255)
    descricao: str | None = None
    secretaria: str = Field(..., min_length=3, max_length=150)
    tipo: str = Field(..., min_length=3, max_length=80)
    secretaria_dam: str | None = None
    tipos_resposta: list[str] = Field(..., min_length=1)
    campos_obrigatorios: dict[str, bool] = Field(default_factory=dict)
    modelo_documento_nome: str | None = Field(default=None, max_length=255)
    modelo_documento_url: str | None = Field(default=None, max_length=500)
    requer_vistoria: bool = False
    checklist_vistoria: list[str] = Field(default_factory=list)


class QuestionResponse(BaseModel):
    id: int
    key: str
    pergunta: str
    descricao: str | None = None
    secretaria: str
    tipo: str
    secretaria_dam: str | None = None
    tipos_resposta: list[str]
    campos_obrigatorios: dict[str, bool]
    modelo_documento_nome: str | None = None
    modelo_documento_url: str | None = None
    requer_vistoria: bool = False
    checklist_vistoria: list[str] = Field(default_factory=list)
    created_at: datetime | None = None
    updated_at: datetime | None = None


class EventPublicRangeRequest(BaseModel):
    label: str = Field(..., min_length=3, max_length=120)
    min_publico: int = Field(..., ge=0)
    max_publico: int = Field(..., ge=1)
    prazo_dias_uteis: int = Field(..., ge=1, le=365)
    is_active: bool = True


class EventPublicRangeResponse(EventPublicRangeRequest):
    id: int


class RequirementResponse(BaseModel):
    id: int
    secretaria: str
    tipo_exigencia: str
    status: str
    observacoes: str | None = None
    requires_inspection: bool = False
    inspection_checklist: list[str] = Field(default_factory=list)
    inspection_scheduled_for: date | None = None
    inspection_status: str = "nao_agendada"
    inspection_result: dict[str, Any] | None = None


class AttachmentCreateRequest(BaseModel):
    nome_arquivo: str = Field(..., min_length=3, max_length=255)
    arquivo_url: str = Field(..., min_length=3, max_length=500)
    mime_type: str | None = Field(default=None, max_length=120)
    tamanho_bytes: int | None = Field(default=None, ge=1)


class DamAttachmentRequest(AttachmentCreateRequest):
    pass


class AttachmentResponse(BaseModel):
    id: int
    tipo_documento: str
    nome_arquivo: str
    arquivo_url: str
    mime_type: str | None = None
    tamanho_bytes: int | None = None


class CommentCreateRequest(BaseModel):
    mensagem: str = Field(..., min_length=2, max_length=2000)
    requirement_id: int | None = None


class CommentResponse(BaseModel):
    id: int
    permit_request_id: int
    requirement_id: int | None = None
    author_id: int
    author_name: str
    mensagem: str
    created_at: datetime | None = None


class RequirementStatusUpdateRequest(BaseModel):
    status: str = Field(..., min_length=3, max_length=50)
    observacoes: str | None = Field(default=None, max_length=2000)


class InspectionScheduleRequest(BaseModel):
    scheduled_for: date


class InspectionCompleteRequest(BaseModel):
    approved: bool
    checklist: dict[str, bool] = Field(default_factory=dict)
    observacoes: str | None = Field(default=None, max_length=2000)
    fotos: list[str] = Field(default_factory=list)
    nova_data: date | None = None


class EventCredentialResponse(BaseModel):
    id: int
    permit_request_id: int
    codigo_publico: str
    status: str
    valid_from: datetime
    valid_until: datetime
    issued_at: datetime | None = None
    verified_at: datetime | None = None
    verification_count: int = 0
    validation_url: str


class EventCredentialValidationResponse(BaseModel):
    valid: bool
    reason: str | None = None
    credential_status: str | None = None
    protocolo: str | None = None
    nome_evento: str | None = None
    data_evento: str | None = None
    horario_inicio: str | None = None
    horario_termino: str | None = None
    local_evento: str | None = None
    responsavel: str | None = None
    publico_estimado: str | None = None
    status_solicitacao: str | None = None
    dam_status: str | None = None
    verified_at: datetime | None = None
    verification_count: int = 0
    requirements: list[RequirementResponse] = []
    dam_attachment: AttachmentResponse | None = None


class EventCredentialRevokeRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=2000)


class AuthorizationTemplateRequest(BaseModel):
    header_text: str = Field(..., min_length=10, max_length=2000)
    footer_text: str = Field(..., min_length=10, max_length=2000)


class AuthorizationTemplateResponse(BaseModel):
    id: int
    slug: str
    header_text: str
    footer_text: str
    updated_at: datetime | None = None


class PermitResponse(BaseModel):
    id: int
    protocolo: str
    tipo: str
    status: str
    dam_status: str
    is_beneficente: bool
    dados_responsavel: dict[str, Any]
    dados_evento: dict[str, Any]
    respostas: dict[str, Any]
    created_at: datetime | None = None
    requirements: list[RequirementResponse] = []
    attachments: list[AttachmentResponse] = []
    comments: list[CommentResponse] = []
    credentials: list[EventCredentialResponse] = []
