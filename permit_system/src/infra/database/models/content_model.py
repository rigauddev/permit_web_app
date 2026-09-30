from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
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


class ServiceConfigModel(Base):
    __tablename__ = "service_configs"

    key = Column(String(80), primary_key=True)
    title = Column(String(120), nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    updated_by = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    updater = relationship("UserModel", foreign_keys=[updated_by])


class ContentSettingModel(Base):
    __tablename__ = "content_settings"

    key = Column(String(100), primary_key=True)
    value = Column(Text, nullable=False)
    updated_by = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    updater = relationship("UserModel", foreign_keys=[updated_by])


class TourismPointModel(Base):
    __tablename__ = "tourism_points"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(120), nullable=False)
    detail = Column(String(255), nullable=False)
    place = Column(String(255), nullable=False)
    category = Column(String(80), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    marker_x = Column(Float, default=0.5, nullable=False)
    marker_y = Column(Float, default=0.5, nullable=False)
    display_order = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    updated_by = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    creator = relationship("UserModel", foreign_keys=[created_by])
    updater = relationship("UserModel", foreign_keys=[updated_by])
