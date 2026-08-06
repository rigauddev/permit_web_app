from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from .base import Base


class HomeContentCardModel(Base):
    __tablename__ = "cards_conteudo_home"

    id = Column(Integer, primary_key=True, index=True)
    scope = Column(String(80), nullable=False, index=True)
    title = Column(String(120), nullable=False)
    body = Column(Text, nullable=False)
    image_url = Column(String(500), nullable=False)
    display_order = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    updated_by = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    creator = relationship("UserModel", foreign_keys=[created_by])
    updater = relationship("UserModel", foreign_keys=[updated_by])
