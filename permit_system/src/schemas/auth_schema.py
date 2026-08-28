from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    identifier: str | None = None
    email: str | None = None
    senha: str = Field(..., min_length=6)
    access_type: str | None = Field(None, pattern="^(cidadao|interno)$")
    client_type: str = Field("web", pattern="^(web|app)$")


class UserSessionResponse(BaseModel):
    id: int
    nome: str
    email: str | None = None
    role: str
    secretaria: str | None = None
    permissions: list[str] = Field(default_factory=list)


class LoginStartResponse(BaseModel):
    mfa_required: bool = True
    challenge_token: str | None = None
    available_methods: list[str] = Field(default_factory=list)
    default_method: str | None = None
    access_token: str | None = None
    token_type: str = "bearer"
    user: UserSessionResponse | None = None


class MfaGenerateRequest(BaseModel):
    challenge_token: str
    method: str = "email"


class MfaGenerateResponse(BaseModel):
    method: str
    delivery: str
    expires_in_seconds: int = 300
    dev_code: str | None = None


class MfaVerifyRequest(BaseModel):
    challenge_token: str
    method: str = "email"
    code: str = Field(..., min_length=6, max_length=6)
    client_type: str = Field("web", pattern="^(web|app)$")


class EmailVerificationStartRequest(BaseModel):
    email: str
    purpose: str = "register"


class EmailVerificationStartResponse(BaseModel):
    email: str
    delivery: str
    expires_in_seconds: int = 600
    dev_code: str | None = None


class EmailVerificationConfirmRequest(BaseModel):
    email: str
    code: str = Field(..., min_length=6, max_length=6)
    purpose: str = "register"


class EmailVerificationConfirmResponse(BaseModel):
    email: str
    verification_token: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserSessionResponse
