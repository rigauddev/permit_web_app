"""Acesso à Orla: immutable vehicle registrations and audited entry checks."""
import os
import re
import secrets
from datetime import date, datetime

import httpx
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel, Field
from typing import Literal
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from src.api.dependencies import get_current_user
from src.core.security import hash_password
from src.infra.database.mysql_db import get_db
from src.infra.database.models import RoleModel, UserModel
from src.infra.database.models.orla_model import OrlaAccount, OrlaVehicle, OrlaAccess, OrlaInn, OrlaGuestPass
from src.services.orla_area import is_inside_orla

router = APIRouter(prefix='/orla', tags=['Acesso à Orla'])

RESPONSIBLE_SECRETARIAS = {
    'semop': 'SEMOP',
    'dmtran': 'DMTRAN',
    'guarda_civil': 'Guarda Municipal',
}


def staff(user):
    return user.role.slug == 'admin' or (
        user.role.slug in ('gestor_secretaria', 'operador_secretaria')
        and user.secretaria and user.secretaria.slug in RESPONSIBLE_SECRETARIAS and user.secretaria.is_active
    )


def responsible_secretaria_user(user):
    return (
        user.role.slug in ('gestor_secretaria', 'operador_secretaria')
        and user.secretaria and user.secretaria.slug in RESPONSIBLE_SECRETARIAS and user.secretaria.is_active
    )


def inspection_staff(user):
    return user.role.slug == 'admin' or (
        user.role.slug in ('gestor_secretaria', 'operador_secretaria')
        and user.secretaria and user.secretaria.slug in {'dmtran', 'guarda_civil'} and user.secretaria.is_active
    )


def _parse_stay_date(value: str | None) -> date | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except ValueError:
        return None


def _stay_allows_orla_access(db: Session, owner: UserModel) -> tuple[bool, str | None]:
    if owner.tipo_usuario != 'turista':
        return True, None
    period_allowed, period_message = _period_allows_orla_access(owner.estadia_inicio, owner.estadia_fim)
    if not period_allowed:
        return False, period_message or 'Acesso fora do período de estadia.'
    if owner.tipo_estadia == 'casa_aluguel':
        if is_inside_orla(owner.estadia_latitude, owner.estadia_longitude):
            return True, None
        return False, 'Casa de aluguel fora da área autorizada da Orla de Guaibim.'
    if owner.tipo_estadia == 'pousada':
        return _inn_status_allows_orla_access(db.get(OrlaInn, owner.pousada_id) if owner.pousada_id else None)
    return False, 'Tipo de estadia do turista não permite validar acesso à Orla.'


def _period_allows_orla_access(start: str | None, end: str | None) -> tuple[bool, str | None]:
    start_date = _parse_stay_date(start)
    end_date = _parse_stay_date(end)
    if not start_date or not end_date:
        return False, 'Período de estadia não informado.'
    today = date.today()
    if today < start_date:
        return False, 'A estadia ainda não iniciou.'
    if today > end_date:
        return False, 'Período de estadia encerrado. Acesso à Orla expirado.'
    return True, None


def _inn_status_allows_orla_access(inn: OrlaInn | None) -> tuple[bool, str | None]:
    if not inn:
        return False, 'Pousada/hotel não encontrada.'
    if not inn.beachfront:
        return False, 'Pousada/hotel fora da área autorizada da Orla de Guaibim.'
    if inn.approval_status != 'approved':
        return False, 'Pousada/hotel da orla ainda não liberada pela gestão.'
    return True, None


def require_staff(user=Depends(get_current_user)):
    if not staff(user):
        raise HTTPException(403, 'Acesso restrito à fiscalização da orla.')
    return user


def require_inspection_staff(user=Depends(get_current_user)):
    if not inspection_staff(user):
        raise HTTPException(403, 'Acesso restrito à fiscalização operacional da orla.')
    return user


def plate(value):
    value = re.sub(r'[^A-Z0-9]', '', (value or '').upper())
    if not re.fullmatch(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}', value):
        raise HTTPException(422, 'Informe uma placa brasileira válida (ABC1234 ou ABC1D23).')
    return value


def plate_from_text(value: str | None) -> str | None:
    cleaned = re.sub(r'[^A-Z0-9]', '', (value or '').upper())
    match = re.search(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}', cleaned)
    return match.group(0) if match else None


def account(db, user_id, locked=False):
    query = db.query(OrlaAccount).filter_by(user_id=user_id)
    if locked:
        query = query.populate_existing().with_for_update()
    row = query.first()
    return row.vehicle_limit if row else 2


def _only_digits(value: str | None) -> str:
    return re.sub(r'\D', '', value or '')


def _valid_cpf(value: str) -> bool:
    if len(value) != 11 or value == value[0] * 11:
        return False
    numbers = [int(digit) for digit in value]
    for size in (9, 10):
        total = sum(numbers[index] * (size + 1 - index) for index in range(size))
        digit = (total * 10) % 11
        if digit == 10:
            digit = 0
        if digit != numbers[size]:
            return False
    return True


def _valid_cnpj(value: str) -> bool:
    if len(value) != 14 or value == value[0] * 14:
        return False
    numbers = [int(digit) for digit in value]
    weights = ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
    for offset, current_weights in enumerate(weights):
        total = sum(numbers[index] * current_weights[index] for index in range(len(current_weights)))
        digit = 11 - (total % 11)
        if digit >= 10:
            digit = 0
        if digit != numbers[12 + offset]:
            return False
    return True


def _split_name(name: str) -> tuple[str, str | None]:
    parts = [part for part in name.strip().split() if part]
    if not parts:
        return ('Hóspede', None)
    return (parts[0], ' '.join(parts[1:]) or None)


def _ensure_guest_user(db: Session, payload, inn: OrlaInn):
    document = _only_digits(payload.guest_document)
    if not (_valid_cpf(document) or _valid_cnpj(document)):
        raise HTTPException(422, 'Informe CPF/CNPJ válido do hóspede para liberar acesso ao sistema.')
    user = db.query(UserModel).filter(UserModel.cpf_cnpj == document).first()
    if not user:
        role = db.query(RoleModel).filter(RoleModel.slug == 'cidadao').first()
        if not role:
            raise HTTPException(500, 'Perfil cidadão não configurado.')
        first_name, last_name = _split_name(payload.guest_name)
        user = UserModel(
            tipo_pessoa='PJ' if len(document) == 14 else 'PF',
            nome=first_name,
            sobrenome=last_name,
            cpf_cnpj=document,
            telefone=(payload.guest_phone or '').strip() or None,
            senha_hash=hash_password(document),
            tipo_usuario='turista',
            tipo_estadia='pousada',
            estadia_inicio=payload.stay_start.strip(),
            estadia_fim=payload.stay_end.strip(),
            pousada_id=inn.id,
            orla_access_requested=True,
            orla_access_status='solicitado',
            role_id=role.id,
            must_change_password=True,
        )
        db.add(user)
        db.flush()
    else:
        user.tipo_usuario = user.tipo_usuario or 'turista'
        user.tipo_estadia = 'pousada'
        user.estadia_inicio = payload.stay_start.strip()
        user.estadia_fim = payload.stay_end.strip()
        user.pousada_id = inn.id
        if payload.guest_phone and not user.telefone:
            user.telefone = payload.guest_phone.strip()
    account_row = db.query(OrlaAccount).filter_by(user_id=user.id).first()
    if not account_row:
        account_row = OrlaAccount(user_id=user.id, vehicle_limit=1)
        db.add(account_row)
    elif account_row.vehicle_limit < 1:
        account_row.vehicle_limit = 1
    normalized_plate = plate(payload.vehicle_plate)
    vehicle = db.query(OrlaVehicle).filter_by(plate=normalized_plate).first()
    if not vehicle:
        db.add(OrlaVehicle(
            user_id=user.id,
            plate=normalized_plate,
            brand=payload.vehicle_brand.strip(),
            model=payload.vehicle_model.strip(),
            color=payload.vehicle_color.strip(),
            establishment_name=inn.name,
            is_excursion=payload.is_excursion,
            driver_name=(payload.excursion_responsible_name or '').strip() or None,
            driver_document=(payload.excursion_responsible_document or '').strip() or None,
            driver_phone=(payload.excursion_responsible_phone or '').strip() or None,
            passengers_count=payload.guest_count,
            qr_token=secrets.token_urlsafe(32),
        ))
    elif vehicle.user_id != user.id:
        raise HTTPException(409, 'Placa já cadastrada para outro usuário.')
    return user


def vehicle_data(db, vehicle, include_qr=False):
    owner = db.get(UserModel, vehicle.user_id)
    stay_allowed, stay_message = _stay_allows_orla_access(db, owner)
    authorized = owner.is_active and stay_allowed and account(db, owner.id) > 0
    inn = db.get(OrlaInn, owner.pousada_id) if owner and owner.pousada_id else None
    status = 'ativo' if authorized else 'nao_autorizado'
    status_label = 'Ativo' if authorized else 'Não autorizado'
    if stay_message and 'encerrado' in stay_message.lower():
        status = 'expirado'
        status_label = 'Acesso expirado'
    elif stay_message and ('ainda não iniciou' in stay_message.lower() or 'fora da área' in stay_message.lower()):
        status_label = stay_message
    data = dict(id=vehicle.id, user_id=owner.id, owner_name=owner.nome,
                plate=vehicle.plate, brand=vehicle.brand, model=vehicle.model, color=vehicle.color,
                establishment_name=vehicle.establishment_name,
                access_type='vehicle',
                user_type=owner.tipo_usuario,
                stay_type=owner.tipo_estadia,
                stay_start=owner.estadia_inicio,
                stay_end=owner.estadia_fim,
                stay_address=owner.estadia_endereco,
                inn_name=inn.name if inn else None,
                is_excursion=bool(vehicle.is_excursion), driver_name=vehicle.driver_name,
                driver_document=vehicle.driver_document, driver_phone=vehicle.driver_phone,
                passengers_count=vehicle.passengers_count,
                inside=vehicle.inside, authorized=authorized,
                access_status=status, access_status_label=status_label,
                authorization_message=stay_message,
                created_at=vehicle.created_at)
    if include_qr:
        # Opaque reference resolves vehicle and owner only after authentication.
        data['qr_code'] = 'ORLA1:' + vehicle.qr_token
    return data


class VehicleInput(BaseModel):
    plate: str = Field(min_length=7, max_length=12)
    brand: str = Field(min_length=1, max_length=80)
    model: str = Field(min_length=1, max_length=100)
    color: str = Field(min_length=1, max_length=50)
    establishment_name: str | None = Field(default=None, max_length=150)
    is_excursion: bool = False
    driver_name: str | None = Field(default=None, max_length=150)
    driver_document: str | None = Field(default=None, max_length=30)
    driver_phone: str | None = Field(default=None, max_length=30)
    passengers_count: int | None = Field(default=None, ge=1, le=200)


class LimitInput(BaseModel):
    vehicle_limit: int = Field(ge=0, le=1000)


class LookupInput(BaseModel):
    value: str = Field(min_length=1, max_length=200)
    method: Literal['qr', 'plate']


class AccessInput(LookupInput):
    action: Literal['entry'] = 'entry'


class InnInput(BaseModel):
    name: str = Field(min_length=2, max_length=150)
    address: str | None = Field(default=None, max_length=255)
    cep: str | None = Field(default=None, max_length=9)
    latitude: str | None = Field(default=None, max_length=40)
    longitude: str | None = Field(default=None, max_length=40)
    capacity: int | None = Field(default=None, ge=1, le=10000)
    parking_capacity: int | None = Field(default=None, ge=1, le=10000)
    guest_capacity: int | None = Field(default=None, ge=1, le=10000)
    beachfront: bool = False


class InnApprovalInput(BaseModel):
    approval_status: Literal['approved', 'pending', 'rejected']
    beachfront: bool | None = None


class GuestPassInput(BaseModel):
    guest_name: str = Field(min_length=2, max_length=150)
    guest_document: str = Field(min_length=11, max_length=30)
    guest_phone: str | None = Field(default=None, max_length=30)
    whatsapp_phone: str | None = Field(default=None, max_length=30)
    stay_start: str = Field(min_length=8, max_length=10)
    stay_end: str = Field(min_length=8, max_length=10)
    vehicle_plate: str = Field(min_length=7, max_length=12)
    vehicle_brand: str = Field(min_length=1, max_length=80)
    vehicle_model: str = Field(min_length=1, max_length=100)
    vehicle_color: str = Field(min_length=1, max_length=50)
    is_excursion: bool = False
    excursion_responsible_name: str | None = Field(default=None, max_length=150)
    excursion_responsible_document: str | None = Field(default=None, max_length=30)
    excursion_responsible_phone: str | None = Field(default=None, max_length=30)
    guest_count: int | None = Field(default=None, ge=1, le=300)
    orla_access_requested: bool = False


def inn_data(inn):
    return {
        'id': inn.id,
        'name': inn.name,
        'address': inn.address,
        'cep': inn.cep,
        'latitude': inn.latitude,
        'longitude': inn.longitude,
        'capacity': inn.capacity,
        'parking_capacity': inn.capacity,
        'guest_capacity': inn.guest_capacity,
        'beachfront': bool(inn.beachfront),
        'approval_status': inn.approval_status,
    }


def guest_pass_data(row, inn: OrlaInn | None = None):
    stay_allowed, stay_message = _period_allows_orla_access(row.stay_start, row.stay_end)
    inn_allowed, inn_message = _inn_status_allows_orla_access(inn)
    authorized = row.status == 'authorized' and stay_allowed and inn_allowed
    message = stay_message or inn_message
    access_status = 'ativo' if authorized else 'nao_autorizado'
    access_status_label = 'Ativo' if authorized else 'Não autorizado'
    if message and 'encerrado' in message.lower():
        access_status = 'expirado'
        access_status_label = 'Acesso expirado'
    elif row.status != 'authorized':
        access_status = 'pendente'
        access_status_label = 'Pendente de liberação'
    elif message:
        access_status_label = message
    return {
        'id': row.id,
        'inn_id': row.inn_id,
        'access_type': 'guest_pass',
        'guest_name': row.guest_name,
        'guest_document': row.guest_document,
        'guest_phone': row.guest_phone,
        'whatsapp_phone': row.whatsapp_phone,
        'stay_start': row.stay_start,
        'stay_end': row.stay_end,
        'vehicle_plate': row.vehicle_plate,
        'vehicle_brand': row.vehicle_brand,
        'vehicle_model': row.vehicle_model,
        'vehicle_color': row.vehicle_color,
        'is_excursion': bool(row.is_excursion),
        'excursion_responsible_name': row.excursion_responsible_name,
        'excursion_responsible_document': row.excursion_responsible_document,
        'excursion_responsible_phone': row.excursion_responsible_phone,
        'guest_count': row.guest_count,
        'qr_code': 'ORLAGUEST1:' + row.qr_token,
        'status': row.status,
        'authorized': authorized,
        'access_status': access_status,
        'access_status_label': access_status_label,
        'authorization_message': message,
        'inn_name': inn.name if inn else None,
        'created_at': row.created_at,
    }


@router.get('/inns')
def inns(include_pending: bool = False, db: Session = Depends(get_db)):
    query = db.query(OrlaInn)
    if not include_pending:
        query = query.filter(OrlaInn.approval_status == 'approved')
    return [inn_data(inn) for inn in query.order_by(OrlaInn.name).all()]


@router.post('/inns', status_code=201)
def create_inn(payload: InnInput, db: Session = Depends(get_db)):
    name = payload.name.strip()
    if db.query(OrlaInn).filter(OrlaInn.name == name).first():
        raise HTTPException(409, 'Pousada já cadastrada.')
    is_beachfront = bool(payload.beachfront or is_inside_orla(payload.latitude, payload.longitude))
    inn = OrlaInn(
        name=name,
        address=(payload.address or '').strip() or None,
        cep=(payload.cep or '').strip() or None,
        latitude=(payload.latitude or '').strip() or None,
        longitude=(payload.longitude or '').strip() or None,
        capacity=payload.parking_capacity or payload.capacity,
        guest_capacity=payload.guest_capacity,
        beachfront=is_beachfront,
        approval_status='pending' if is_beachfront else 'approved',
    )
    db.add(inn)
    db.commit()
    db.refresh(inn)
    return inn_data(inn)


@router.put('/inns/{inn_id}/approval')
def approve_inn(inn_id: int, payload: InnApprovalInput, db: Session = Depends(get_db), user=Depends(require_staff)):
    if user.role.slug not in ('admin', 'gestor_secretaria', 'operador_secretaria'):
        raise HTTPException(403, 'Somente gestão ou operação autorizada pode validar estabelecimentos da orla.')
    inn = db.get(OrlaInn, inn_id)
    if not inn:
        raise HTTPException(404, 'Estabelecimento não encontrado.')
    if payload.beachfront is not None:
        inn.beachfront = payload.beachfront
    inn.approval_status = payload.approval_status
    db.commit()
    return inn_data(inn)


@router.get('/me')
def me(db: Session = Depends(get_db), user=Depends(get_current_user)):
    if user.role.slug != 'cidadao' and not staff(user):
        raise HTTPException(403, 'Serviço disponível ao cidadão e à fiscalização da orla.')
    return dict(vehicle_limit=account(db, user.id), is_staff=bool(staff(user)),
                role=user.role.slug,
                secretaria=user.secretaria.slug if user.secretaria else None,
                can_manage=bool(staff(user) and user.role.slug in ('admin', 'gestor_secretaria')),
                can_view_dashboard=bool(responsible_secretaria_user(user)),
                business_category=user.business_category,
                managed_inn_id=user.managed_inn_id,
                can_register_guests=bool(user.role.slug == 'cidadao' and user.business_category == 'pousada_hotel' and user.managed_inn_id),
                responsible_secretarias=list(RESPONSIBLE_SECRETARIAS.values()),
                vehicles=[vehicle_data(db, v, True) for v in db.query(OrlaVehicle).filter_by(user_id=user.id).all()])


@router.post('/vehicles', status_code=201)
def register(payload: VehicleInput, db: Session = Depends(get_db), user=Depends(get_current_user)):
    if user.role.slug != 'cidadao':
        raise HTTPException(403, 'Cadastro disponível ao cidadão.')
    normalized = plate(payload.plate)
    if not payload.brand.strip() or not payload.model.strip() or not payload.color.strip():
        raise HTTPException(422, 'Marca, modelo e cor são obrigatórios.')
    # Serializes registrations and limit changes, including the first registration.
    db.execute(update(UserModel).where(UserModel.id == user.id).values(id=UserModel.id))
    count = len(db.query(OrlaVehicle).filter_by(user_id=user.id).with_for_update().all())
    if count >= account(db, user.id, locked=True):
        db.rollback()
        raise HTTPException(409, 'Limite de veículos atingido. Procure a gestão responsável.')
    if payload.is_excursion and not (payload.driver_name and payload.passengers_count):
        raise HTTPException(422, 'Informe dados do motorista e quantidade de passageiros da excursão.')
    vehicle = OrlaVehicle(user_id=user.id, plate=normalized, brand=payload.brand.strip(), model=payload.model.strip(),
                          color=payload.color.strip(), establishment_name=(payload.establishment_name or '').strip() or None,
                          is_excursion=payload.is_excursion, driver_name=(payload.driver_name or '').strip() or None,
                          driver_document=(payload.driver_document or '').strip() or None,
                          driver_phone=(payload.driver_phone or '').strip() or None, passengers_count=payload.passengers_count,
                          qr_token=secrets.token_urlsafe(32))
    db.add(vehicle)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, 'Placa já cadastrada.')
    db.refresh(vehicle)
    return vehicle_data(db, vehicle, True)


@router.get('/guest-passes')
def guest_passes(db: Session = Depends(get_db), user=Depends(get_current_user)):
    query = db.query(OrlaGuestPass)
    if staff(user):
        pass
    elif user.role.slug == 'cidadao' and user.managed_inn_id:
        query = query.filter(OrlaGuestPass.inn_id == user.managed_inn_id)
    else:
        raise HTTPException(403, 'Acesso restrito a pousadas/hotéis e fiscalização.')
    rows = query.order_by(OrlaGuestPass.id.desc()).limit(200).all()
    return [guest_pass_data(row, db.get(OrlaInn, row.inn_id)) for row in rows]


@router.post('/guest-passes', status_code=201)
def create_guest_pass(payload: GuestPassInput, db: Session = Depends(get_db), user=Depends(get_current_user)):
    if not (user.role.slug == 'cidadao' and user.business_category == 'pousada_hotel' and user.managed_inn_id):
        raise HTTPException(403, 'Somente pousadas/hotéis podem cadastrar hóspedes.')
    inn = db.get(OrlaInn, user.managed_inn_id)
    if not inn:
        raise HTTPException(404, 'Pousada/hotel não encontrado.')
    if inn.beachfront and inn.approval_status != 'approved':
        raise HTTPException(403, 'Pousada na orla ainda não liberada pela gestão.')
    if payload.is_excursion and not (payload.excursion_responsible_name and payload.guest_count):
        raise HTTPException(422, 'Informe responsável e quantidade de hóspedes da excursão.')
    if payload.orla_access_requested:
        _ensure_guest_user(db, payload, inn)
    row = OrlaGuestPass(
        inn_id=inn.id,
        created_by=user.id,
        guest_name=payload.guest_name.strip(),
        guest_document=(payload.guest_document or '').strip() or None,
        guest_phone=(payload.guest_phone or '').strip() or None,
        whatsapp_phone=(payload.whatsapp_phone or payload.guest_phone or '').strip() or None,
        stay_start=payload.stay_start.strip(),
        stay_end=payload.stay_end.strip(),
        vehicle_plate=plate(payload.vehicle_plate),
        vehicle_brand=payload.vehicle_brand.strip(),
        vehicle_model=payload.vehicle_model.strip(),
        vehicle_color=payload.vehicle_color.strip(),
        is_excursion=payload.is_excursion,
        excursion_responsible_name=(payload.excursion_responsible_name or '').strip() or None,
        excursion_responsible_document=(payload.excursion_responsible_document or '').strip() or None,
        excursion_responsible_phone=(payload.excursion_responsible_phone or '').strip() or None,
        guest_count=payload.guest_count,
        qr_token=secrets.token_urlsafe(32),
        status='authorized' if payload.orla_access_requested else 'pending',
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return guest_pass_data(row, inn)


@router.get('/reports')
def reports(start: str | None = None, end: str | None = None, db: Session = Depends(get_db), user=Depends(require_staff)):
    if not responsible_secretaria_user(user):
        raise HTTPException(403, 'Dashboard disponível para DMTRAN e Guarda Municipal.')
    users_query = db.query(UserModel).filter(UserModel.role.has(slug='cidadao'))
    if start:
        users_query = users_query.filter(UserModel.created_at >= start)
    if end:
        users_query = users_query.filter(UserModel.created_at <= end)
    users = users_query.all()
    tourists = [u for u in users if u.tipo_usuario == 'turista']
    residents = [u for u in users if u.tipo_usuario == 'morador']
    inns_rows = db.query(OrlaInn).all()
    passes = db.query(OrlaGuestPass).all()
    vehicles = db.query(OrlaVehicle).all()
    tourists_by_inn = {}
    for user_row in tourists:
        if user_row.pousada_id:
            inn = db.get(OrlaInn, user_row.pousada_id)
            name = inn.name if inn else 'Pousada não encontrada'
            tourists_by_inn[name] = tourists_by_inn.get(name, 0) + 1
    for row in passes:
        inn = db.get(OrlaInn, row.inn_id)
        name = inn.name if inn else 'Pousada não encontrada'
        tourists_by_inn[name] = tourists_by_inn.get(name, 0) + (row.guest_count or 1)
    tourists_by_month = {}
    for user_row in tourists:
        key = str(user_row.created_at or '')[:7] or 'sem_data'
        tourists_by_month[key] = tourists_by_month.get(key, 0) + 1
    for row in passes:
        key = (row.stay_start or '')[-4:] + '-' + (row.stay_start or '')[3:5] if len(row.stay_start or '') >= 10 else 'sem_data'
        tourists_by_month[key] = tourists_by_month.get(key, 0) + (row.guest_count or 1)
    inn_occupancy = []
    exceeded_inns = []
    for inn in inns_rows:
        inn_passes = [row for row in passes if row.inn_id == inn.id]
        used = len({row.vehicle_plate for row in inn_passes})
        guests_used = sum((row.guest_count or 1) for row in inn_passes)
        capacity = inn.capacity
        guest_capacity = inn.guest_capacity
        exceeded = bool(capacity is not None and used > capacity)
        guests_exceeded = bool(guest_capacity is not None and guests_used > guest_capacity)
        occupancy = {
            'id': inn.id,
            'name': inn.name,
            'capacity': capacity,
            'parking_capacity': capacity,
            'guest_capacity': guest_capacity,
            'occupied': used,
            'parking_occupied': used,
            'guest_occupied': guests_used,
            'beachfront': bool(inn.beachfront),
            'approval_status': inn.approval_status,
            'available': max(capacity - used, 0) if capacity is not None else None,
            'exceeded_by': used - capacity if exceeded else 0,
            'guest_exceeded_by': guests_used - guest_capacity if guests_exceeded else 0,
            'exceeded': exceeded,
            'guest_exceeded': guests_exceeded,
        }
        inn_occupancy.append(occupancy)
        if exceeded or guests_exceeded:
            exceeded_inns.append(occupancy)
    busiest_month = max(tourists_by_month.items(), key=lambda item: item[1], default=(None, 0))
    return {
        'summary': {
            'users': len(users),
            'residents': len(residents),
            'tourists': sum(tourists_by_month.values()) or len(tourists),
            'inns': len(inns_rows),
            'beachfront_inns': len([item for item in inns_rows if item.beachfront]),
            'guest_passes': len(passes),
            'excursions': len([item for item in passes if item.is_excursion]) + len([item for item in vehicles if item.is_excursion]),
            'vehicles': len(vehicles),
            'inns_over_capacity': len(exceeded_inns),
            'busiest_month': busiest_month[0],
            'busiest_month_total': busiest_month[1],
        },
        'user_type': {'Moradores': len(residents), 'Turistas': len(tourists)},
        'tourists_by_inn': tourists_by_inn,
        'inn_occupancy': sorted(inn_occupancy, key=lambda item: (not item['exceeded'], item['name'])),
        'inns_over_capacity': exceeded_inns,
        'tourists_by_month': dict(sorted(tourists_by_month.items())),
        'inns_status': {
            'Liberadas': len([item for item in inns_rows if item.approval_status == 'approved']),
            'Pendentes': len([item for item in inns_rows if item.approval_status == 'pending']),
            'Recusadas': len([item for item in inns_rows if item.approval_status == 'rejected']),
        },
    }


@router.get('/users')
def users(q: str = '', offset: int = 0, db: Session = Depends(get_db), user=Depends(require_inspection_staff)):
    rows = db.query(UserModel).filter(
        UserModel.role.has(slug='cidadao'),
        UserModel.id.in_(db.query(OrlaVehicle.user_id).distinct()),
    )
    if q.strip():
        term = '%' + q.strip() + '%'
        rows = rows.filter((UserModel.nome.ilike(term)) | UserModel.id.in_(
            db.query(OrlaVehicle.user_id).filter(OrlaVehicle.plate.ilike(term))))
    return [dict(id=u.id, name=u.nome, active=u.is_active, vehicle_limit=account(db, u.id),
                 vehicles=[vehicle_data(db, v) for v in db.query(OrlaVehicle).filter_by(user_id=u.id).all()])
            for u in rows.order_by(UserModel.nome, UserModel.id).offset(max(0, offset)).limit(50).all()]


@router.put('/users/{user_id}/limit')
def set_limit(user_id: int, payload: LimitInput, db: Session = Depends(get_db), user=Depends(require_staff)):
    if user.role.slug not in ('admin', 'gestor_secretaria'):
        raise HTTPException(403, 'Somente a gestão da fiscalização da orla pode alterar limites.')
    owner = db.get(UserModel, user_id)
    if not owner or owner.role.slug != 'cidadao':
        raise HTTPException(404, 'Cidadão não encontrado.')
    db.execute(update(UserModel).where(UserModel.id == user_id).values(id=UserModel.id))
    row = db.query(OrlaAccount).filter_by(user_id=user_id).populate_existing().with_for_update().first()
    if not row:
        row = OrlaAccount(user_id=user_id)
        db.add(row)
    row.vehicle_limit = payload.vehicle_limit
    db.commit()
    return {'vehicle_limit': row.vehicle_limit}


def resolve(db, payload):
    if payload.method == 'qr':
        if payload.value.startswith('ORLAGUEST1:'):
            guest = db.query(OrlaGuestPass).filter_by(qr_token=payload.value[11:]).first()
            if not guest:
                raise HTTPException(404, 'Credencial de hóspede não encontrada.')
            return ('guest', guest)
        if not payload.value.startswith('ORLA1:'):
            detected_plate = plate_from_text(payload.value)
            if detected_plate:
                vehicle = db.query(OrlaVehicle).filter_by(plate=detected_plate).first()
                if not vehicle:
                    raise HTTPException(404, 'Placa lida no QR Code não cadastrada. Acesso não autorizado.')
                return ('vehicle', vehicle)
            raise HTTPException(422, 'QR Code não pertence ao serviço Acesso à Orla e não contém placa reconhecível.')
        query = db.query(OrlaVehicle).filter_by(qr_token=payload.value[6:])
    else:
        query = db.query(OrlaVehicle).filter_by(plate=plate(payload.value))
    vehicle = query.first()
    if not vehicle:
        raise HTTPException(404, 'Veículo não cadastrado. Acesso não autorizado.')
    return ('vehicle', vehicle)


@router.post('/lookup')
def lookup(payload: LookupInput, db: Session = Depends(get_db), user=Depends(require_inspection_staff)):
    kind, item = resolve(db, payload)
    if kind == 'guest':
        inn = db.get(OrlaInn, item.inn_id)
        data = guest_pass_data(item, inn)
        data.update({
            'plate': item.vehicle_plate,
            'brand': item.vehicle_brand,
            'model': item.vehicle_model,
            'color': item.vehicle_color,
            'owner_name': item.guest_name,
            'guest_name': item.guest_name,
            'establishment_name': inn.name if inn else None,
            'inn_name': inn.name if inn else None,
        })
        return data
    return vehicle_data(db, item)


@router.post('/plate-security')
async def plate_security(payload: LookupInput, user=Depends(require_inspection_staff)):
    if payload.method != 'plate':
        raise HTTPException(422, 'Informe uma placa para consultar restrição.')
    normalized = plate(payload.value)
    url = os.getenv('VEHICLE_RESTRICTION_API_URL', '').strip()
    token = os.getenv('VEHICLE_RESTRICTION_API_TOKEN', '').strip()
    if not url:
        return {
            'configured': False,
            'plate': normalized,
            'status': 'unavailable',
            'stolen': None,
            'message': 'Consulta de furto/roubo não configurada.',
        }
    try:
        headers = {'Accept': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        async with httpx.AsyncClient(timeout=15) as client:
            if '{plate}' in url:
                response = await client.get(url.replace('{plate}', normalized), headers=headers)
            else:
                response = await client.get(url, params={'plate': normalized}, headers=headers)
            response.raise_for_status()
            data = response.json()
        stolen = _restriction_flag(data)
        message = _restriction_message(data, stolen)
        return {
            'configured': True,
            'plate': normalized,
            'status': 'checked',
            'stolen': stolen,
            'message': message,
            'source': data.get('source') if isinstance(data, dict) else None,
        }
    except (httpx.HTTPError, ValueError, TypeError):
        raise HTTPException(502, 'Não foi possível consultar furto/roubo. Tente novamente ou consulte manualmente.')


def _restriction_flag(data) -> bool:
    if not isinstance(data, dict):
        return False
    for key in ('stolen', 'roubo_furto', 'theft_robbery', 'has_restriction', 'restriction'):
        value = data.get(key)
        if isinstance(value, bool):
            return value
        if isinstance(value, str) and value.strip().lower() in {'sim', 'true', 'roubo', 'furto', 'roubo/furto', 'restricao'}:
            return True
    status_text = ' '.join(str(data.get(key, '')) for key in ('status', 'situacao', 'message', 'mensagem')).lower()
    return any(term in status_text for term in ('roubo', 'furto', 'restri'))


def _restriction_message(data, stolen: bool) -> str:
    if isinstance(data, dict):
        for key in ('message', 'mensagem', 'situacao', 'status'):
            value = data.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return 'Alerta de furto/roubo encontrado.' if stolen else 'Nenhuma restrição de furto/roubo encontrada.'


@router.post('/accesses', status_code=201)
def movement(payload: AccessInput, db: Session = Depends(get_db), user=Depends(require_inspection_staff)):
    kind, vehicle = resolve(db, payload)
    if kind == 'guest':
        data = lookup(payload, db, user)
        if not data.get('authorized'):
            raise HTTPException(403, data.get('authorization_message') or 'Credencial de hóspede sem autorização.')
        data['access_registered'] = True
        data['authorization_message'] = 'Acesso validado para entrada na Orla de Guaibim.'
        return data
    db.execute(update(UserModel).where(UserModel.id == vehicle.user_id).values(id=UserModel.id))
    owner = db.query(UserModel).filter_by(id=vehicle.user_id).populate_existing().with_for_update().one()
    stay_allowed, stay_message = _stay_allows_orla_access(db, owner)
    if not stay_allowed:
        db.rollback()
        raise HTTPException(403, stay_message or 'Acesso fora do período de estadia.')
    authorized = owner.is_active and account(db, owner.id, locked=True) > 0
    if not authorized:
        db.rollback()
        raise HTTPException(403, 'Veículo sem autorização para entrada.')
    db.add(OrlaAccess(vehicle_id=vehicle.id, operator_id=user.id, action='entry', method=payload.method))
    db.commit()
    data = vehicle_data(db, vehicle)
    data['access_registered'] = True
    data['authorization_message'] = 'Acesso validado para entrada na Orla de Guaibim.'
    return data


@router.get('/vehicles/{vehicle_id}/accesses')
def history(vehicle_id: int, offset: int = 0, db: Session = Depends(get_db), user=Depends(get_current_user)):
    vehicle = db.get(OrlaVehicle, vehicle_id)
    if not vehicle or (vehicle.user_id != user.id and not staff(user)):
        raise HTTPException(404, 'Veículo não encontrado.')
    return [dict(id=a.id, action=a.action, method=a.method, created_at=a.created_at)
            for a in db.query(OrlaAccess).filter_by(vehicle_id=vehicle_id)
            .order_by(OrlaAccess.id.desc()).offset(max(0, offset)).limit(100).all()]


@router.post('/recognize-plate')
async def recognize(file: UploadFile = File(...), user=Depends(require_inspection_staff)):
    token = os.getenv('PLATE_RECOGNIZER_TOKEN', '')
    if not token:
        raise HTTPException(
            503,
            'Leitura automática de letras/números da placa não configurada. '
            'Digite a placa manualmente ou leia o QR Code gerado pelo sistema.',
        )
    if file.content_type not in ('image/jpeg', 'image/png', 'image/webp'):
        raise HTTPException(422, 'Envie uma foto JPEG, PNG ou WebP.')
    image = await file.read(5 * 1024 * 1024 + 1)
    if not image or len(image) > 5 * 1024 * 1024:
        raise HTTPException(413, 'Envie uma foto de até 5 MB.')
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post('https://api.platerecognizer.com/v1/plate-reader/',
                headers={'Authorization': 'Token ' + token}, data={'regions': 'br'},
                files={'upload': ('plate.jpg', image, file.content_type)})
            response.raise_for_status()
            results = response.json()['results']
        candidates = []
        for result in results:
            value = str(result.get('plate', '')).upper()
            if re.fullmatch(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}', value):
                candidates.append({'plate': value, 'score': result.get('score', 0)})
        return {'candidates': candidates}
    except (httpx.HTTPError, ValueError, KeyError, TypeError):
        raise HTTPException(502, 'Não foi possível ler a placa. Tente outra foto ou digite a placa.')
