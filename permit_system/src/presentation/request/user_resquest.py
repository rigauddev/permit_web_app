
from pydantic import BaseModel, Field


class UserRequest(BaseModel):
    email: str = Field(..., description="Email do usuário")
    senha: str = Field(..., description="Senha do usuário")
    nome: str = Field(..., description="Nome do usuário")
    sobrenome: str = Field(..., description="Sobrenome do usuário")
    telefone: str = Field(..., description="Telefone do usuário")
    endereco: str = Field(..., description="Endereço do usuário")
    cpf: str = Field(..., description="CPF do usuário")
    tipo_usuario: str = Field(..., description="Tipo de usuário")
    role: str = Field(..., description="Role do usuário")
    secretaria_id: str = Field(..., description="Secretaria do usuário")
    