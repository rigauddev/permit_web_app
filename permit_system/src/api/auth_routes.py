from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user, require_roles
from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db
from src.schemas.auth_schema import (
    EmailVerificationConfirmRequest,
    EmailVerificationConfirmResponse,
    EmailVerificationStartRequest,
    EmailVerificationStartResponse,
    LoginRequest,
    LoginStartResponse,
    MfaGenerateRequest,
    MfaGenerateResponse,
    MfaVerifyRequest,
    TokenResponse,
)
from src.schemas.user_schema import UserCreateRequest, UserResponse
from src.services.auth_service import AuthService


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginStartResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    return AuthService(db).start_login(str(payload.email), payload.senha, payload.access_type)


@router.post("/mfa/generate", response_model=MfaGenerateResponse)
def generate_mfa(payload: MfaGenerateRequest, db: Session = Depends(get_db)):
    return AuthService(db).generate_mfa_code(payload.challenge_token, payload.method)


@router.post("/mfa/verify", response_model=TokenResponse)
def verify_mfa(payload: MfaVerifyRequest, db: Session = Depends(get_db)):
    return AuthService(db).verify_mfa_code(payload.challenge_token, payload.method, payload.code)


@router.post("/email-verifications", response_model=EmailVerificationStartResponse)
def start_email_verification(payload: EmailVerificationStartRequest, db: Session = Depends(get_db)):
    return AuthService(db).start_email_verification(payload.email, payload.purpose)


@router.post("/email-verifications/confirm", response_model=EmailVerificationConfirmResponse)
def confirm_email_verification(payload: EmailVerificationConfirmRequest, db: Session = Depends(get_db)):
    return AuthService(db).confirm_email_verification(payload.email, payload.code, payload.purpose)


@router.post("/register", response_model=UserResponse)
def register(payload: UserCreateRequest, db: Session = Depends(get_db)):
    return AuthService(db).create_user(
        payload,
        force_role="cidadao",
        force_secretaria=None,
        require_email_verification=True,
    )


@router.post("/company-users", response_model=UserResponse)
def create_company_user(
    payload: UserCreateRequest,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    secretaria = payload.secretaria
    if current_user.role.slug == "gestor_secretaria":
        if payload.role == "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Gestor de secretaria não pode criar administrador",
            )
        secretaria = current_user.secretaria.slug if current_user.secretaria else None
    return AuthService(db).create_user(payload, force_secretaria=secretaria)


@router.get("/me", response_model=UserResponse)
def me(current_user: UserModel = Depends(get_current_user)):
    return AuthService.to_response(current_user)


@router.get("/users", response_model=list[UserResponse])
def list_users(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(require_roles("admin", "gestor_secretaria")),
):
    query = db.query(UserModel)
    if current_user.role.slug == "gestor_secretaria":
        query = query.filter(UserModel.secretaria_id == current_user.secretaria_id)
    users = query.order_by(UserModel.nome).all()
    return [AuthService.to_response(user) for user in users]
