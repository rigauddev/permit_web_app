from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from .base import Base


class OrlaAccount(Base):
    __tablename__ = 'orla_accounts'
    user_id = Column(Integer, ForeignKey('usuarios.id'), primary_key=True)
    vehicle_limit = Column(Integer, nullable=False, default=2)


class OrlaInn(Base):
    __tablename__ = 'orla_inns'
    id = Column(Integer, primary_key=True)
    name = Column(String(150), nullable=False, unique=True)
    address = Column(String(255), nullable=True)
    cep = Column(String(9), nullable=True)
    latitude = Column(String(40), nullable=True)
    longitude = Column(String(40), nullable=True)
    # Compatibilidade: capacity representa vagas de estacionamento.
    capacity = Column(Integer, nullable=True)
    guest_capacity = Column(Integer, nullable=True)
    beachfront = Column(Boolean, nullable=False, default=False)
    approval_status = Column(String(30), nullable=False, default='approved')
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)


class OrlaVehicle(Base):
    __tablename__ = 'orla_vehicles'
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('usuarios.id'), nullable=False, index=True)
    plate = Column(String(7), nullable=False, unique=True)
    brand = Column(String(80), nullable=False, default='Nao informado')
    model = Column(String(100), nullable=False)
    color = Column(String(50), nullable=False)
    establishment_name = Column(String(150), nullable=True)
    is_excursion = Column(Boolean, nullable=False, default=False)
    driver_name = Column(String(150), nullable=True)
    driver_document = Column(String(30), nullable=True)
    driver_phone = Column(String(30), nullable=True)
    passengers_count = Column(Integer, nullable=True)
    qr_token = Column(String(100), nullable=False, unique=True)
    inside = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)


class OrlaAccess(Base):
    __tablename__ = 'orla_accesses'
    id = Column(Integer, primary_key=True)
    vehicle_id = Column(Integer, ForeignKey('orla_vehicles.id'), nullable=False, index=True)
    operator_id = Column(Integer, ForeignKey('usuarios.id'), nullable=False)
    action = Column(String(10), nullable=False)
    method = Column(String(10), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)


class OrlaGuestPass(Base):
    __tablename__ = 'orla_guest_passes'
    id = Column(Integer, primary_key=True)
    inn_id = Column(Integer, ForeignKey('orla_inns.id'), nullable=False, index=True)
    created_by = Column(Integer, ForeignKey('usuarios.id'), nullable=False, index=True)
    guest_name = Column(String(150), nullable=False)
    guest_document = Column(String(30), nullable=True)
    guest_phone = Column(String(30), nullable=True)
    whatsapp_phone = Column(String(30), nullable=True)
    stay_start = Column(String(10), nullable=False)
    stay_end = Column(String(10), nullable=False)
    vehicle_plate = Column(String(7), nullable=False, index=True)
    vehicle_brand = Column(String(80), nullable=False)
    vehicle_model = Column(String(100), nullable=False)
    vehicle_color = Column(String(50), nullable=False)
    is_excursion = Column(Boolean, nullable=False, default=False)
    excursion_responsible_name = Column(String(150), nullable=True)
    excursion_responsible_document = Column(String(30), nullable=True)
    excursion_responsible_phone = Column(String(30), nullable=True)
    guest_count = Column(Integer, nullable=True)
    qr_token = Column(String(100), nullable=False, unique=True)
    status = Column(String(30), nullable=False, default='authorized')
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)
