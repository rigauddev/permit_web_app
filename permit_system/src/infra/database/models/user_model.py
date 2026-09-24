from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
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
    permissions = relationship("RolePermissionModel", back_populates="role")


class PermissionModel(Base):
    __tablename__ = "permissions"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(100), unique=True, nullable=False, index=True)
    nome = Column(String(120), nullable=False)
    categoria = Column(String(80), nullable=False, index=True)
    descricao = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    roles = relationship("RolePermissionModel", back_populates="permission")


class RolePermissionModel(Base):
    __tablename__ = "role_permissions"

    id = Column(Integer, primary_key=True, index=True)
    role_id = Column(Integer, ForeignKey("roles.id"), nullable=False, index=True)
    permission_id = Column(Integer, ForeignKey("permissions.id"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    role = relationship("RoleModel", back_populates="permissions")
    permission = relationship("PermissionModel", back_populates="roles")


class SecretariaModel(Base):
    __tablename__ = "secretarias"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(80), unique=True, nullable=False, index=True)
    nome = Column(String(150), nullable=False)
    descricao = Column(String(255), nullable=True)
    email = Column(String(255), nullable=True)
    logo_url = Column(String(500), nullable=True)
    email_header_text = Column(Text, nullable=True)
    document_header_text = Column(Text, nullable=True)
    document_footer_text = Column(Text, nullable=True)
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
    cpf_cnpj = Column(String(18), unique=True, nullable=True, index=True)
    credential_number = Column(String(40), unique=True, nullable=True, index=True)
    email = Column(String(255), unique=False, nullable=True, index=True)
    senha_hash = Column(String(255), nullable=False)
    telefone = Column(String(20), nullable=True)
    endereco = Column(String(255), nullable=True)
    cep = Column(String(9), nullable=True)
    endereco_latitude = Column(String(40), nullable=True)
    endereco_longitude = Column(String(40), nullable=True)
    tipo_usuario = Column(String(20), default="morador", nullable=False)
    business_category = Column(String(40), nullable=True)
    managed_inn_id = Column(Integer, ForeignKey("orla_inns.id"), nullable=True)
    tipo_estadia = Column(String(30), nullable=True)
    estadia_endereco = Column(String(255), nullable=True)
    estadia_cep = Column(String(9), nullable=True)
    estadia_latitude = Column(String(40), nullable=True)
    estadia_longitude = Column(String(40), nullable=True)
    estadia_inicio = Column(String(10), nullable=True)
    estadia_fim = Column(String(10), nullable=True)
    pousada_id = Column(Integer, ForeignKey("orla_inns.id"), nullable=True)
    orla_access_requested = Column(Boolean, default=False, nullable=False)
    orla_access_status = Column(String(30), default="nao_solicitado", nullable=False)
    foto_usuario_url = Column(String(500), nullable=True)
    foto_usuario_nome = Column(String(255), nullable=True)
    documento_identificacao_url = Column(String(500), nullable=True)
    documento_identificacao_nome = Column(String(255), nullable=True)
    documento_identificacao_tipo = Column(String(50), nullable=True)
    comprovante_residencia_url = Column(String(500), nullable=True)
    comprovante_residencia_nome = Column(String(255), nullable=True)
    comprovante_residencia_tipo = Column(String(50), nullable=True)
    comprovante_residencia_status = Column(String(50), default="pendente_validacao", nullable=False)
    comprovante_residencia_observacao = Column(Text, nullable=True)
    alvara_funcionamento_url = Column(String(500), nullable=True)
    alvara_funcionamento_nome = Column(String(255), nullable=True)
    role_id = Column(Integer, ForeignKey("roles.id"), nullable=False)
    secretaria_id = Column(Integer, ForeignKey("secretarias.id"), nullable=True)
    mfa_email_enabled = Column(Boolean, default=False, nullable=False)
    mfa_totp_enabled = Column(Boolean, default=False, nullable=False)
    mfa_code_hash = Column(String(255), nullable=True)
    mfa_code_expires_at = Column(DateTime(timezone=True), nullable=True)
    must_change_password = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    role = relationship("RoleModel", back_populates="users")
    secretaria = relationship("SecretariaModel", back_populates="users")
    permit_requests = relationship("PermitRequestModel", back_populates="solicitante")


class EmailVerificationModel(Base):
    __tablename__ = "verificacoes_email"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), nullable=False, index=True)
    purpose = Column(String(50), default="register", nullable=False)
    code_hash = Column(String(255), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
