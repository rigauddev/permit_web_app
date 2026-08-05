from typing import Optional
from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from src.entities import BaseModelDefault


class UserEntity(BaseModelDefault):
    id: str = Field("", description="User id")
    email: str = Field(..., description="User email")
    senha: str = Field(..., description="User password")
    nome: str = Field(..., description="User name")
    sobrenome: str = Field("", description="User last name")
    telefone: str = Field("", description="User phone")
    endereco: str = Field("", description="User address")
    cpf: str = Field(..., description="User CPF")
    tipo_usuario: str = Field("", description="User type")
    role: str = Field("", description="User role")
    secretaria_id: str = Field("", description="User secretaria id")
    created_at: datetime = Field(datetime.now(), description="User created at")
    updated_at: datetime = Field(datetime.now(), description="User updated at")
    deleted_at: datetime = Field(None, description="User deleted at")
    is_active: bool = Field(True, description="User is active")
    @field_validator("id", mode="before")
    def convert_id_to_int(cls, id):
        if id is None:
            return None
        return int(id)