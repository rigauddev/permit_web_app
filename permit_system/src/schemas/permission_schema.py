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


class RoleCreateRequest(BaseModel):
    slug: str = Field(..., min_length=3, max_length=50, pattern="^[a-z0-9_]+$")
    nome: str = Field(..., min_length=3, max_length=100)
    descricao: str | None = Field(default=None, max_length=255)
    permissions: list[str] = Field(default_factory=list)


class PermissionMatrixResponse(BaseModel):
    permissions: list[PermissionResponse]
    roles: list[RolePermissionResponse]


class RolePermissionUpdateRequest(BaseModel):
    permissions: list[str] = Field(default_factory=list)
