from pydantic import BaseModel, Field


class UserVehicleCreateRequest(BaseModel):
    plate: str = Field(..., min_length=7, max_length=12)
    brand: str = Field(..., min_length=1, max_length=80)
    model: str = Field(..., min_length=1, max_length=100)
    color: str = Field(..., min_length=1, max_length=50)
    establishment_name: str | None = Field(default=None, max_length=150)
    is_excursion: bool = False
    driver_name: str | None = Field(default=None, max_length=150)
    driver_document: str | None = Field(default=None, max_length=30)
    driver_phone: str | None = Field(default=None, max_length=30)
    passengers_count: int | None = Field(default=None, ge=1, le=200)


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
    cep: str | None = None
    endereco_latitude: str | None = None
    endereco_longitude: str | None = None
    tipo_usuario: str = Field("morador", pattern="^(morador|turista)$")
    business_category: str | None = Field(default=None, pattern="^(pousada_hotel|restaurante|quiosque)$")
    managed_inn_name: str | None = Field(default=None, max_length=150)
    managed_inn_capacity: int | None = Field(default=None, ge=1, le=10000)
    managed_inn_guest_capacity: int | None = Field(default=None, ge=1, le=10000)
    tipo_estadia: str | None = Field(default=None, pattern="^(casa_aluguel|pousada)$")
    estadia_endereco: str | None = None
    estadia_cep: str | None = None
    estadia_latitude: str | None = None
    estadia_longitude: str | None = None
    estadia_inicio: str | None = None
    estadia_fim: str | None = None
    pousada_id: int | None = None
    orla_access_requested: bool = False
    orla_vehicle: UserVehicleCreateRequest | None = None
    role: str = "cidadao"
    secretaria: str | None = None
    email_verification_token: str | None = None
    termo_responsabilidade_aceito: bool = False
    foto_usuario_nome: str | None = None
    foto_usuario_url: str | None = None
    documento_identificacao_nome: str | None = None
    documento_identificacao_url: str | None = None
    documento_identificacao_tipo: str | None = None
    comprovante_residencia_nome: str | None = None
    comprovante_residencia_url: str | None = None
    comprovante_residencia_tipo: str | None = None
    alvara_funcionamento_nome: str | None = None
    alvara_funcionamento_url: str | None = None
    mfa_email_enabled: bool = False


class UserSelfUpdateRequest(BaseModel):
    nome: str | None = Field(default=None, min_length=2, max_length=255)
    sobrenome: str | None = Field(default=None, max_length=255)
    telefone: str | None = Field(default=None, max_length=20)
    endereco: str | None = Field(default=None, max_length=255)
    foto_usuario_nome: str | None = Field(default=None, max_length=255)
    foto_usuario_url: str | None = Field(default=None, max_length=500)
    mfa_email_enabled: bool | None = None


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
    cep: str | None = None
    tipo_usuario: str | None = None
    business_category: str | None = None
    managed_inn_id: int | None = None
    tipo_estadia: str | None = None
    estadia_endereco: str | None = None
    estadia_cep: str | None = None
    estadia_inicio: str | None = None
    estadia_fim: str | None = None
    orla_access_requested: bool = False
    orla_access_status: str | None = None
    foto_usuario_url: str | None = None
    documento_identificacao_url: str | None = None
    comprovante_residencia_url: str | None = None
    comprovante_residencia_status: str | None = None
    alvara_funcionamento_url: str | None = None
    role: str
    secretaria: str | None = None
    permissions: list[str] = Field(default_factory=list)
    must_change_password: bool = False
    mfa_email_enabled: bool = False
    is_active: bool
