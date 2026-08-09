from datetime import datetime

from pydantic import BaseModel, Field


class SecretariaRequest(BaseModel):
    slug: str = Field(..., min_length=3, max_length=80, pattern="^[a-z0-9_]+$")
    nome: str = Field(..., min_length=3, max_length=150)
    descricao: str | None = Field(default=None, max_length=255)
    email: str | None = Field(default=None, max_length=255)
    logo_url: str | None = Field(default=None, max_length=500)
    email_header_text: str | None = Field(default=None, max_length=2000)
    document_header_text: str | None = Field(default=None, max_length=3000)
    document_footer_text: str | None = Field(default=None, max_length=3000)
    is_active: bool = True


class SecretariaResponse(BaseModel):
    id: int
    slug: str
    nome: str
    descricao: str | None = None
    email: str | None = None
    logo_url: str | None = None
    email_header_text: str | None = None
    document_header_text: str | None = None
    document_footer_text: str | None = None
    is_active: bool
    created_at: datetime | None = None
