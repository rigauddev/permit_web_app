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
