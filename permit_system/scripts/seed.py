import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from src.core.security import hash_password
from src.infra.database.models import PermitRequestModel, PermitRequirementModel, RoleModel, SecretariaModel, UserModel
from src.infra.database.mysql_db import SessionLocal, create_tables


ROLES = [
    ("admin", "Administrador", "Acesso total ao sistema"),
    ("gestor_secretaria", "Gestor de Secretaria", "Acompanha solicitações da secretaria"),
    ("operador_secretaria", "Operador de Secretaria", "Analisa solicitações da secretaria"),
    ("cidadao", "Cidadão", "Solicita e acompanha alvarás"),
]

SECRETARIAS = [
    ("desenvolvimento_economico", "Secretaria de Desenvolvimento Econômico"),
    ("meio_ambiente", "Secretaria de Meio Ambiente"),
    ("infraestrutura", "Secretaria de Infraestrutura"),
    ("dmtran", "DMTRAN"),
    ("vigilancia_sanitaria", "Vigilância Sanitária"),
    ("guarda_civil", "Guarda Civil Municipal"),
    ("receita_municipal", "Receita Municipal"),
]


def get_or_create(db, model, defaults=None, **filters):
    instance = db.query(model).filter_by(**filters).first()
    if instance:
        return instance
    params = {**filters, **(defaults or {})}
    instance = model(**params)
    db.add(instance)
    db.flush()
    return instance


def seed_roles(db):
    roles = {}
    for slug, nome, descricao in ROLES:
        roles[slug] = get_or_create(db, RoleModel, slug=slug, defaults={"nome": nome, "descricao": descricao})
    return roles


def seed_secretarias(db):
    secretarias = {}
    for slug, nome in SECRETARIAS:
        secretarias[slug] = get_or_create(db, SecretariaModel, slug=slug, defaults={"nome": nome})
    return secretarias


def seed_users(db, roles, secretarias):
    password = hash_password("123456")
    users = [
        {
            "email": "admin@prefeitura.local",
            "nome": "Administrador",
            "cpf_cnpj": "00000000000",
            "role_id": roles["admin"].id,
        },
        {
            "email": "cidadao@teste.local",
            "nome": "Maria Solicitante",
            "cpf_cnpj": "11111111111",
            "role_id": roles["cidadao"].id,
        },
        {
            "email": "meioambiente@prefeitura.local",
            "nome": "Operador Meio Ambiente",
            "cpf_cnpj": "22222222222",
            "role_id": roles["operador_secretaria"].id,
            "secretaria_id": secretarias["meio_ambiente"].id,
        },
        {
            "email": "dmtran@prefeitura.local",
            "nome": "Operador DMTRAN",
            "cpf_cnpj": "33333333333",
            "role_id": roles["operador_secretaria"].id,
            "secretaria_id": secretarias["dmtran"].id,
        },
        {
            "email": "gestor@prefeitura.local",
            "nome": "Gestor Desenvolvimento Econômico",
            "cpf_cnpj": "44444444444",
            "role_id": roles["gestor_secretaria"].id,
            "secretaria_id": secretarias["desenvolvimento_economico"].id,
        },
    ]

    created = {}
    for data in users:
        created[data["email"]] = get_or_create(
            db,
            UserModel,
            email=data["email"],
            defaults={
                "tipo_pessoa": "PF",
                "nome": data["nome"],
                "cpf_cnpj": data["cpf_cnpj"],
                "senha_hash": password,
                "telefone": "(75) 99999-0000",
                "endereco": "Valença - BA",
                "role_id": data["role_id"],
                "secretaria_id": data.get("secretaria_id"),
                "mfa_email_enabled": True,
                "mfa_totp_enabled": False,
            },
        )
    return created


def seed_permit_request(db, users, secretarias):
    existing = db.query(PermitRequestModel).filter_by(protocolo="ALV-SEED-0001").first()
    if existing:
        return existing

    request = PermitRequestModel(
        protocolo="ALV-SEED-0001",
        solicitante_id=users["cidadao@teste.local"].id,
        tipo="alvara_evento",
        status="em_analise",
        dam_status="pendente_prefeitura",
        is_beneficente=False,
        dados_responsavel={
            "nome": "Maria Solicitante",
            "cpf_cnpj": "11111111111",
            "telefone": "(75) 99999-0000",
            "email": "cidadao@teste.local",
            "endereco": "Valença - BA",
        },
        dados_evento={
            "nome_evento": "Festa Teste MVP",
            "data_evento": "2026-08-25",
            "endereco_evento": "Praça Central",
            "publico_estimado": 300,
            "horario_inicio": "18:00",
            "horario_termino": "23:00",
            "anexos_informados": [
                "rg_cpf.pdf",
                "comprovante_residencia.pdf",
                "alvara_funcionamento.pdf",
            ],
        },
        respostas={
            "tem_som": True,
            "tem_palco": False,
            "tem_gerador": False,
            "tem_trio_eletrico": True,
            "bloqueia_via": True,
            "tem_alimentacao": False,
            "precisa_guarda": False,
        },
    )
    db.add(request)
    db.flush()

    db.add_all(
        [
            PermitRequirementModel(
                permit_request_id=request.id,
                secretaria_id=secretarias["meio_ambiente"].id,
                tipo_exigencia="Termo de Responsabilidade Ambiental",
            ),
            PermitRequirementModel(
                permit_request_id=request.id,
                secretaria_id=secretarias["dmtran"].id,
                tipo_exigencia="Vistoria de trio elétrico, CNH do motorista e mapa do circuito",
            ),
            PermitRequirementModel(
                permit_request_id=request.id,
                secretaria_id=secretarias["dmtran"].id,
                tipo_exigencia="Autorização para uso ou bloqueio de via pública",
            ),
        ]
    )
    return request


def main():
    create_tables()
    db = SessionLocal()
    try:
        roles = seed_roles(db)
        secretarias = seed_secretarias(db)
        users = seed_users(db, roles, secretarias)
        seed_permit_request(db, users, secretarias)
        db.commit()
        print("Seed executado com sucesso.")
        print("Usuários de teste: admin@prefeitura.local, cidadao@teste.local, meioambiente@prefeitura.local")
        print("Senha padrão: 123456")
    finally:
        db.close()


if __name__ == "__main__":
    main()
