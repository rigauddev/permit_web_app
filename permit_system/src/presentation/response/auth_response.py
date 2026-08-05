from pydantic import BaseModel

class TokenResponse(BaseModel):
    access_token: str
    token_type: str

class UserResponse(BaseModel):
    id: int
    nome: str
    email: str
    telefone: str
    endereco: str