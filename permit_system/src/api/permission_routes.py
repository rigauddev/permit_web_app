from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from src.api.dependencies import require_roles
from src.infra.database.models import PermissionModel, RoleModel, RolePermissionModel, UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.permission_schema import (
    PermissionMatrixResponse,
    PermissionResponse,
    RolePermissionResponse,
    RolePermissionUpdateRequest,
)


router = APIRouter(prefix="/permissions", tags=["permissions"])


@router.get("", response_model=PermissionMatrixResponse)
def list_permission_matrix(
    db: Session = Depends(get_db),
    _: UserModel = Depends(require_roles("admin")),
):
    permissions = db.query(PermissionModel).filter(PermissionModel.is_active.is_(True)).order_by(
        PermissionModel.categoria.asc(),
        PermissionModel.nome.asc(),
    ).all()
    roles = db.query(RoleModel).filter(RoleModel.is_active.is_(True)).order_by(RoleModel.nome.asc()).all()
    return PermissionMatrixResponse(
        permissions=[
            PermissionResponse(
                slug=permission.slug,
                nome=permission.nome,
                categoria=permission.categoria,
                descricao=permission.descricao,
            )
            for permission in permissions
        ],
        roles=[
            RolePermissionResponse(
                slug=role.slug,
                nome=role.nome,
                descricao=role.descricao,
                permissions=sorted(
                    role_permission.permission.slug
                    for role_permission in role.permissions
                    if role_permission.permission and role_permission.permission.is_active
                ),
            )
            for role in roles
        ],
    )


@router.put("/roles/{role_slug}", response_model=RolePermissionResponse)
def update_role_permissions(
    role_slug: str,
    payload: RolePermissionUpdateRequest,
    db: Session = Depends(get_db),
    _: UserModel = Depends(require_roles("admin")),
):
    if role_slug == "admin":
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="As permissões do administrador não podem ser reduzidas.",
        )
    role = db.query(RoleModel).filter(RoleModel.slug == role_slug, RoleModel.is_active.is_(True)).first()
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Perfil não encontrado")

    permissions = (
        db.query(PermissionModel)
        .filter(PermissionModel.slug.in_(payload.permissions), PermissionModel.is_active.is_(True))
        .all()
    )
    found_slugs = {permission.slug for permission in permissions}
    missing = set(payload.permissions) - found_slugs
    if missing:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Permissão inválida")

    db.query(RolePermissionModel).filter(RolePermissionModel.role_id == role.id).delete()
    for permission in permissions:
        db.add(RolePermissionModel(role_id=role.id, permission_id=permission.id))
    db.commit()
    db.refresh(role)
    return RolePermissionResponse(
        slug=role.slug,
        nome=role.nome,
        descricao=role.descricao,
        permissions=sorted(
            role_permission.permission.slug
            for role_permission in role.permissions
            if role_permission.permission and role_permission.permission.is_active
        ),
    )
