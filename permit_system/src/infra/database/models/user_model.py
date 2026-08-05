from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from .base import Base


class RoleModel(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(50), unique=True, nullable=False, index=True)
    nome = Column(String(100), nullable=False)
    descricao = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    users = relationship("UserModel", back_populates="role")


class SecretariaModel(Base):
    __tablename__ = "secretarias"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(80), unique=True, nullable=False, index=True)
    nome = Column(String(150), nullable=False)
    descricao = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    users = relationship("UserModel", back_populates="secretaria")
    requirements = relationship("PermitRequirementModel", back_populates="secretaria")


class UserModel(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    tipo_pessoa = Column(String(2), default="PF", nullable=False)
    nome = Column(String(255), nullable=False)
    sobrenome = Column(String(255), nullable=True)
    razao_social = Column(String(255), nullable=True)
    cpf_cnpj = Column(String(18), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    senha_hash = Column(String(255), nullable=False)
    telefone = Column(String(20), nullable=True)
    endereco = Column(String(255), nullable=True)
    role_id = Column(Integer, ForeignKey("roles.id"), nullable=False)
    secretaria_id = Column(Integer, ForeignKey("secretarias.id"), nullable=True)
    mfa_email_enabled = Column(Boolean, default=True, nullable=False)
    mfa_totp_enabled = Column(Boolean, default=False, nullable=False)
    mfa_code_hash = Column(String(255), nullable=True)
    mfa_code_expires_at = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    role = relationship("RoleModel", back_populates="users")
    secretaria = relationship("SecretariaModel", back_populates="users")
    permit_requests = relationship("PermitRequestModel", back_populates="solicitante")
