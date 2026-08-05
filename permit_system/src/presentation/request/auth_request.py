from pydantic import BaseModel
from pydantic import Field

class UserLoginRequest(BaseModel):
    email: str = Field(..., description="Email do usuário")
    senha: str =  Field(..., description="Senha do usuário")

class VerifyOTPRequest(BaseModel):
    email: str = Field(..., description="Email do usuário")
    senha: str = Field(..., description="Senha do usuário")
    otp: str = Field(..., description="Código de verificação")