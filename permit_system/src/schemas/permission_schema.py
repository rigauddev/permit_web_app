from pydantic import BaseModel, Field


class PermissionResponse(BaseModel):
    slug: str
    nome: str
    categoria: str
    descricao: str | None = None


class RolePermissionResponse(BaseModel):
    slug: str
    nome: str
    descricao: str | None = None
    permissions: list[str] = Field(default_factory=list)


class PermissionMatrixResponse(BaseModel):
    permissions: list[PermissionResponse]
    roles: list[RolePermissionResponse]


class RolePermissionUpdateRequest(BaseModel):
    permissions: list[str] = Field(default_factory=list)
