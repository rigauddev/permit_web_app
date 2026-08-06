from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field


class PermitCreateRequest(BaseModel):
    is_beneficente: bool = False
    instituicao_beneficiada: str | None = None
    dados_responsavel: dict[str, Any]
    dados_evento: dict[str, Any]
    respostas: dict[str, Any] = Field(default_factory=dict)


class RequirementResponse(BaseModel):
    id: int
    secretaria: str
    tipo_exigencia: str
    status: str
    observacoes: str | None = None


class DamAttachmentRequest(BaseModel):
    nome_arquivo: str = Field(..., min_length=3, max_length=255)
    arquivo_url: str = Field(..., min_length=3, max_length=500)
    mime_type: str | None = Field(default=None, max_length=120)
    tamanho_bytes: int | None = Field(default=None, ge=1)


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


class EventCredentialResponse(BaseModel):
    id: int
    permit_request_id: int
    codigo_publico: str
    status: str
    valid_from: datetime
    valid_until: datetime
    issued_at: datetime | None = None
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
    requirements: list[RequirementResponse] = []
    dam_attachment: AttachmentResponse | None = None


class EventCredentialRevokeRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=2000)


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
