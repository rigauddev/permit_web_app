import os

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from src.infra.database.models import UserModel
from src.infra.database.mysql_db import get_db


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> UserModel:
    try:
        payload = jwt.decode(
            token,
            os.getenv("SECRET_KEY", "change-me-in-production"),
            algorithms=[os.getenv("JWT_ALGORITHM", "HS256")],
        )
        user_id = payload.get("sub")
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido") from exc

    user = db.query(UserModel).filter(UserModel.id == int(user_id), UserModel.is_active.is_(True)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuário inválido")
    return user


def require_roles(*roles: str):
    def checker(current_user: UserModel = Depends(get_current_user)) -> UserModel:
        if current_user.role.slug not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão insuficiente")
        return current_user

    return checker
