from pydantic import BaseModel, Field


class UserCreateRequest(BaseModel):
    tipo_pessoa: str = Field("PF", pattern="^(PF|PJ)$")
    nome: str = Field(..., min_length=2)
    sobrenome: str | None = None
    razao_social: str | None = None
    cpf_cnpj: str | None = Field(default=None, min_length=11, max_length=18)
    email: str | None = None
    senha: str = Field(..., min_length=6)
    telefone: str | None = None
    endereco: str | None = None
    role: str = "cidadao"
    secretaria: str | None = None
    email_verification_token: str | None = None
    termo_responsabilidade_aceito: bool = False
    foto_usuario_nome: str | None = None
    foto_usuario_url: str | None = None
    comprovante_residencia_nome: str | None = None
    comprovante_residencia_url: str | None = None
    comprovante_residencia_tipo: str | None = None
    mfa_email_enabled: bool = False


class UserSelfUpdateRequest(BaseModel):
    nome: str | None = Field(default=None, min_length=2, max_length=255)
    sobrenome: str | None = Field(default=None, max_length=255)
    telefone: str | None = Field(default=None, max_length=20)
    endereco: str | None = Field(default=None, max_length=255)
    foto_usuario_nome: str | None = Field(default=None, max_length=255)
    foto_usuario_url: str | None = Field(default=None, max_length=500)


class UserAdminUpdateRequest(UserSelfUpdateRequest):
    email: str | None = None
    role: str | None = Field(default=None, max_length=50)
    secretaria: str | None = Field(default=None, max_length=80)
    is_active: bool | None = None


class UserResponse(BaseModel):
    id: int
    tipo_pessoa: str
    nome: str
    sobrenome: str | None = None
    razao_social: str | None = None
    cpf_cnpj: str | None = None
    email: str | None = None
    telefone: str | None = None
    endereco: str | None = None
    foto_usuario_url: str | None = None
    comprovante_residencia_url: str | None = None
    comprovante_residencia_status: str | None = None
    role: str
    secretaria: str | None = None
    permissions: list[str] = Field(default_factory=list)
    must_change_password: bool = False
    is_active: bool
