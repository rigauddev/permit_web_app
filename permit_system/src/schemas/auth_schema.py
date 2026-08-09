from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    email: str
    senha: str = Field(..., min_length=6)
    access_type: str | None = Field(None, pattern="^(cidadao|interno)$")


class LoginStartResponse(BaseModel):
    mfa_required: bool = True
    challenge_token: str
    available_methods: list[str]
    default_method: str = "email"


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


class UserSessionResponse(BaseModel):
    id: int
    nome: str
    email: str
    role: str
    secretaria: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserSessionResponse
