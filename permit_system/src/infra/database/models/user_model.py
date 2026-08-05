from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func

Base = declarative_base()

class UserModel(Base):
    __tablename__ = "usuarios"
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(255), nullable=False)
    sobrenome = Column(String(255))
    email = Column(String(255), unique=True, nullable=False)
    senha = Column(String(255), nullable=False)
    telefone = Column(String(20))
    endereco = Column(String(255))
    tipo_usuario = Column(String(255))
    role = Column(String(255))
    secretaria_id = Column(Integer)
    cpf = Column(String(11), unique=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    is_active = Column(Integer, default=1)