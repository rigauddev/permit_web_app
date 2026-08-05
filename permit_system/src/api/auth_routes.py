from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.auth_schema import LoginRequest, TokenResponse
from src.schemas.user_schema import UserCreateRequest, UserResponse
from src.services.auth_service import AuthService


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    return AuthService(db).authenticate(str(payload.email), payload.senha)


@router.post("/register", response_model=UserResponse)
def register(payload: UserCreateRequest, db: Session = Depends(get_db)):
    return AuthService(db).create_user(payload)


@router.get("/me", response_model=UserResponse)
def me(current_user: UserModel = Depends(get_current_user)):
    return AuthService.to_response(current_user)


@router.get("/users", response_model=list[UserResponse])
def list_users(
    db: Session = Depends(get_db),
    _: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    users = db.query(UserModel).order_by(UserModel.nome).all()
    return [AuthService.to_response(user) for user in users]
