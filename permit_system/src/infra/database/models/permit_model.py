from sqlalchemy import Boolean, Column, Date, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from .base import Base


class PermitRequestModel(Base):
    __tablename__ = "solicitacoes_alvara"

    id = Column(Integer, primary_key=True, index=True)
    protocolo = Column(String(40), unique=True, nullable=False, index=True)
    solicitante_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    tipo = Column(String(80), default="alvara_evento", nullable=False)
    status = Column(String(50), default="enviada", nullable=False)
    dam_status = Column(String(50), default="nao_gerado", nullable=False)
    is_beneficente = Column(Boolean, default=False, nullable=False)
    instituicao_beneficiada = Column(String(255), nullable=True)
    dados_responsavel = Column(JSON, nullable=False)
    dados_evento = Column(JSON, nullable=False)
    respostas = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    solicitante = relationship("UserModel", back_populates="permit_requests")
    requirements = relationship("PermitRequirementModel", back_populates="permit_request")
    attachments = relationship("AttachmentModel", back_populates="permit_request")


class PermitRequirementModel(Base):
    __tablename__ = "exigencias_alvara"

    id = Column(Integer, primary_key=True, index=True)
    permit_request_id = Column(Integer, ForeignKey("solicitacoes_alvara.id"), nullable=False)
    secretaria_id = Column(Integer, ForeignKey("secretarias.id"), nullable=False)
    tipo_exigencia = Column(String(120), nullable=False)
    status = Column(String(50), default="aguardando_analise", nullable=False)
    observacoes = Column(Text, nullable=True)
    due_date = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    permit_request = relationship("PermitRequestModel", back_populates="requirements")
    secretaria = relationship("SecretariaModel", back_populates="requirements")
    attachments = relationship("AttachmentModel", back_populates="requirement")


class AttachmentModel(Base):
    __tablename__ = "anexos"

    id = Column(Integer, primary_key=True, index=True)
    permit_request_id = Column(Integer, ForeignKey("solicitacoes_alvara.id"), nullable=False)
    requirement_id = Column(Integer, ForeignKey("exigencias_alvara.id"), nullable=True)
    tipo_documento = Column(String(100), nullable=False)
    nome_arquivo = Column(String(255), nullable=False)
    arquivo_url = Column(String(500), nullable=False)
    mime_type = Column(String(120), nullable=True)
    tamanho_bytes = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    permit_request = relationship("PermitRequestModel", back_populates="attachments")
    requirement = relationship("PermitRequirementModel", back_populates="attachments")
