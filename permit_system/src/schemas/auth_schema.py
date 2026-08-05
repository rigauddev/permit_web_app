from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    email: str
    senha: str = Field(..., min_length=6)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserSessionResponse"


class UserSessionResponse(BaseModel):
    id: int
    nome: str
    email: str
    role: str
    secretaria: str | None = None


TokenResponse.model_rebuild()
