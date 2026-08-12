import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import inspect, text

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from src.core.security import create_event_credential_token, hash_password, hash_token
from src.infra.database.models import (
    AttachmentModel,
    Base,
    EventCredentialModel,
    EventPublicRangeModel,
    HomeContentCardModel,
    PermissionModel,
    PermitRequestModel,
    PermitRequirementModel,
    RoleModel,
    RolePermissionModel,
    SecretariaModel,
    UserModel,
)
from src.infra.database.mysql_db import SessionLocal, create_tables, engine


ROLES = [
    ("admin", "Administrador", "Acesso total ao sistema"),
    ("gestor_secretaria", "Gestor de Secretaria", "Acompanha solicitações da secretaria"),
    ("operador_secretaria", "Operador de Secretaria", "Analisa solicitações da secretaria"),
    ("cidadao", "Cidadão", "Solicita e acompanha alvarás"),
]

PERMISSIONS = [
    ("dashboard.view", "Visualizar dashboard", "Navegação", "Acessa a página inicial adequada ao perfil."),
    ("services.catalog.view", "Visualizar catálogo de serviços", "Serviços", "Acessa os serviços disponíveis ao cidadão."),
    ("services.favorite.manage", "Gerenciar favoritos", "Serviços", "Marca e consulta serviços favoritos."),
    ("requests.own.create", "Criar solicitações próprias", "Solicitações", "Cria solicitação de alvará de eventos."),
    ("requests.own.view", "Visualizar solicitações próprias", "Solicitações", "Consulta apenas solicitações criadas pelo próprio usuário."),
    ("requests.secretaria.view", "Visualizar central da secretaria", "Atendimento", "Consulta solicitações vinculadas à secretaria do usuário."),
    ("requests.secretaria.analyze", "Analisar solicitações da secretaria", "Atendimento", "Aprova, recusa, comenta ou pede correção em exigências da secretaria."),
    ("inspections.view", "Visualizar vistorias", "Vistorias", "Consulta vistorias agendadas da secretaria."),
    ("inspections.manage", "Gerenciar vistorias", "Vistorias", "Agenda, executa e registra checklist/laudo de vistoria."),
    ("dam.attach", "Anexar DAM", "DAM e Alvará", "Anexa DAM quando todas as anuências aplicáveis estiverem concluídas."),
    ("dam.payment_proof.attach", "Anexar comprovante de DAM", "DAM e Alvará", "Permite anexar comprovante de pagamento do DAM pelo cidadão."),
    ("permit.final.attach", "Anexar alvará final", "DAM e Alvará", "Anexa PDF final do alvará após pagamento/isento."),
    ("event_credential.validate", "Validar credencial de evento", "Credencial", "Lê e valida QR Code/credencial pública do evento."),
    ("management.users.manage", "Gerenciar usuários", "Gestão", "Cria e lista usuários conforme escopo do perfil."),
    ("management.secretarias.manage", "Gerenciar secretarias", "Gestão", "Configura secretarias, logo, textos e e-mail."),
    ("management.home_content.manage", "Gerenciar conteúdo da home", "Gestão", "Cria cards de carrossel da prefeitura/secretarias."),
    ("management.services.manage", "Gerenciar serviços", "Gestão de Serviços", "Configura serviços municipais disponíveis no sistema."),
    ("management.questions.manage", "Gerenciar perguntas", "Gestão de Serviços", "Cria perguntas, tipos de resposta, modelos e checklist de vistoria."),
    ("management.event_deadlines.manage", "Gerenciar prazos por público", "Gestão de Serviços", "Configura faixas de público e prazo mínimo em dias úteis para alvará de eventos."),
    ("management.permissions.manage", "Gerenciar permissões", "Permissões", "Mantém matriz de permissões por perfil."),
]

ROLE_PERMISSIONS = {
    "cidadao": {
        "dashboard.view",
        "services.catalog.view",
        "services.favorite.manage",
        "requests.own.create",
        "requests.own.view",
        "dam.payment_proof.attach",
        "event_credential.validate",
    },
    "operador_secretaria": {
        "dashboard.view",
        "requests.secretaria.view",
        "requests.secretaria.analyze",
        "inspections.view",
        "inspections.manage",
        "event_credential.validate",
    },
    "gestor_secretaria": {
        "dashboard.view",
        "requests.secretaria.view",
        "requests.secretaria.analyze",
        "inspections.view",
        "inspections.manage",
        "management.users.manage",
        "management.home_content.manage",
        "management.services.manage",
        "management.questions.manage",
        "management.event_deadlines.manage",
        "event_credential.validate",
    },
    "admin": "all",
}

SECRETARIAS = [
    ("desenvolvimento_economico", "Secretaria de Desenvolvimento Econômico", "sde@valenca.ba.gov.br", "Coordenação da Central de Eventos"),
    ("meio_ambiente", "Secretaria de Meio Ambiente", "meioambiente@valenca.ba.gov.br", "Responsabilidade ambiental"),
    ("infraestrutura", "Secretaria de Infraestrutura", "infraestrutura@valenca.ba.gov.br", "Análise técnica de estruturas"),
    ("dmtran", "DMTRAN", "dmtran@valenca.ba.gov.br", "Mobilidade, trânsito e vias públicas"),
    ("vigilancia_sanitaria", "Vigilância Sanitária", "visa@valenca.ba.gov.br", "Saúde, alimentação e apoio sanitário"),
    ("guarda_civil", "Guarda Civil Municipal", "gcm@valenca.ba.gov.br", "Ordem pública e apoio operacional"),
    ("receita_municipal", "Receita Municipal", "receita@valenca.ba.gov.br", "DAM e arrecadação municipal"),
]

LEGACY_TEST_USERS = {
    "meio_ambiente": [
        ("meioambiente@prefeitura.local", "Operador Meio Ambiente", "operador_secretaria"),
    ],
    "dmtran": [
        ("dmtran@prefeitura.local", "Operador DMTRAN", "operador_secretaria"),
    ],
    "receita_municipal": [
        ("receita@prefeitura.local", "Operador Receita Municipal", "operador_secretaria"),
    ],
    "desenvolvimento_economico": [
        ("gestor@prefeitura.local", "Gestor Desenvolvimento Econômico", "gestor_secretaria"),
    ],
}


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


def seed_permissions(db, roles):
    permissions = {}
    for slug, nome, categoria, descricao in PERMISSIONS:
        permission = get_or_create(
            db,
            PermissionModel,
            slug=slug,
            defaults={
                "nome": nome,
                "categoria": categoria,
                "descricao": descricao,
            },
        )
        permission.nome = nome
        permission.categoria = categoria
        permission.descricao = descricao
        permissions[slug] = permission

    for role_slug, assigned_permissions in ROLE_PERMISSIONS.items():
        role = roles[role_slug]
        slugs = set(permissions) if assigned_permissions == "all" else set(assigned_permissions)
        for permission_slug in slugs:
            existing = (
                db.query(RolePermissionModel)
                .filter_by(role_id=role.id, permission_id=permissions[permission_slug].id)
                .first()
            )
            if not existing:
                db.add(
                    RolePermissionModel(
                        role_id=role.id,
                        permission_id=permissions[permission_slug].id,
                    )
                )
    return permissions


def seed_secretarias(db):
    secretarias = {}
    for slug, nome, email, header in SECRETARIAS:
        defaults = {
            "nome": nome,
            "email": email,
            "logo_url": f"docs/imagens/logo/{slug}.png",
            "email_header_text": f"Prefeitura Municipal de Valença - {header}",
            "document_header_text": f"{nome}\nPrefeitura Municipal de Valença",
            "document_footer_text": "Documento gerado eletronicamente pelo Sistema Municipal de Serviços.",
            "is_active": True,
        }
        secretaria = get_or_create(
            db,
            SecretariaModel,
            slug=slug,
            defaults=defaults,
        )
        for key, value in defaults.items():
            if not getattr(secretaria, key, None):
                setattr(secretaria, key, value)
        secretaria.is_active = True
        secretarias[slug] = secretaria
    return secretarias


def ensure_secretaria_columns():
    inspector = inspect(engine)
    if "secretarias" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("secretarias")}
    migrations = {
        "email": "ALTER TABLE secretarias ADD COLUMN email VARCHAR(255) NULL",
        "logo_url": "ALTER TABLE secretarias ADD COLUMN logo_url VARCHAR(500) NULL",
        "email_header_text": "ALTER TABLE secretarias ADD COLUMN email_header_text TEXT NULL",
        "document_header_text": "ALTER TABLE secretarias ADD COLUMN document_header_text TEXT NULL",
        "document_footer_text": "ALTER TABLE secretarias ADD COLUMN document_footer_text TEXT NULL",
    }
    with engine.begin() as connection:
        for column, statement in migrations.items():
            if column not in columns:
                connection.execute(text(statement))


def ensure_question_definition_columns():
    inspector = inspect(engine)
    if "question_definitions" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("question_definitions")}
    migrations = {
        "modelo_documento_nome": "ALTER TABLE question_definitions ADD COLUMN modelo_documento_nome VARCHAR(255) NULL",
        "modelo_documento_url": "ALTER TABLE question_definitions ADD COLUMN modelo_documento_url VARCHAR(500) NULL",
        "requer_vistoria": "ALTER TABLE question_definitions ADD COLUMN requer_vistoria BOOLEAN NOT NULL DEFAULT 0",
        "checklist_vistoria": "ALTER TABLE question_definitions ADD COLUMN checklist_vistoria JSON NULL",
        "prazo_resposta_dias_uteis": "ALTER TABLE question_definitions ADD COLUMN prazo_resposta_dias_uteis INTEGER NOT NULL DEFAULT 2",
    }
    with engine.begin() as connection:
        for column, statement in migrations.items():
            if column not in columns:
                connection.execute(text(statement))


def ensure_event_credential_columns():
    inspector = inspect(engine)
    if "credenciais_evento" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("credenciais_evento")}
    migrations = {
        "verified_at": "ALTER TABLE credenciais_evento ADD COLUMN verified_at DATETIME NULL",
        "verification_count": "ALTER TABLE credenciais_evento ADD COLUMN verification_count INTEGER NOT NULL DEFAULT 0",
    }
    with engine.begin() as connection:
        for column, statement in migrations.items():
            if column not in columns:
                connection.execute(text(statement))


def ensure_requirement_inspection_columns():
    inspector = inspect(engine)
    if "exigencias_alvara" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("exigencias_alvara")}
    migrations = {
        "requires_inspection": "ALTER TABLE exigencias_alvara ADD COLUMN requires_inspection BOOLEAN NOT NULL DEFAULT 0",
        "inspection_checklist": "ALTER TABLE exigencias_alvara ADD COLUMN inspection_checklist JSON NULL",
        "inspection_scheduled_for": "ALTER TABLE exigencias_alvara ADD COLUMN inspection_scheduled_for DATE NULL",
        "inspection_status": "ALTER TABLE exigencias_alvara ADD COLUMN inspection_status VARCHAR(50) NOT NULL DEFAULT 'nao_agendada'",
        "inspection_result": "ALTER TABLE exigencias_alvara ADD COLUMN inspection_result JSON NULL",
    }
    with engine.begin() as connection:
        for column, statement in migrations.items():
            if column not in columns:
                connection.execute(text(statement))


QUESTION_DEFINITIONS = [
    {
        "key": "tem_som",
        "pergunta": "O evento terá som?",
        "descricao": "Verifica se o evento possui som potencialmente impactante",
        "secretaria": "Meio Ambiente",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
        "prazo_resposta_dias_uteis": 2,
    },
    {
        "key": "local_fixo_sem_alvara",
        "pergunta": "O evento será em local fixo sem alvará de funcionamento válido?",
        "descricao": "Identifica locais que precisam regularizar o alvará de funcionamento",
        "secretaria": "Desenvolvimento Econômico",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
    },
    {
        "key": "precisa_avcb",
        "pergunta": "O evento exige Auto de Vistoria do Corpo de Bombeiros?",
        "descricao": "Avalia a necessidade de vistoria do Corpo de Bombeiros",
        "secretaria": "Infraestrutura",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Anexar Documento", "Texto"],
        "campos_obrigatorios": {"Anexar Documento": False, "Texto": False},
        "requer_vistoria": True,
        "checklist_vistoria": ["Conferir AVCB apresentado", "Conferir saídas de emergência", "Conferir extintores/sinalização"],
    },
    {
        "key": "tem_palco",
        "pergunta": "O evento terá palco ou estrutura montada?",
        "descricao": "Aciona vistoria e ART para montagem de estrutura",
        "secretaria": "Infraestrutura",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
        "requer_vistoria": True,
        "checklist_vistoria": ["Conferir estabilidade da estrutura", "Conferir ART", "Verificar isolamento da área"],
    },
    {
        "key": "tem_gerador",
        "pergunta": "O evento terá gerador?",
        "descricao": "Aciona vistoria e ART do gerador",
        "secretaria": "Infraestrutura",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
        "requer_vistoria": True,
        "checklist_vistoria": ["Conferir instalação elétrica", "Conferir aterramento", "Verificar isolamento do gerador"],
    },
    {
        "key": "precisa_planta_baixa",
        "pergunta": "Evento particular de médio/grande porte em local fixo exigirá planta baixa?",
        "descricao": "Registra necessidade de planta baixa para análise técnica",
        "secretaria": "Infraestrutura",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Anexar Documento", "Texto"],
        "campos_obrigatorios": {"Anexar Documento": False, "Texto": False},
    },
    {
        "key": "tem_trio_eletrico",
        "pergunta": "O evento terá trio elétrico?",
        "descricao": "Aciona vistoria do veículo, CNH do motorista e mapa do circuito",
        "secretaria": "DMTRAN",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto", "Anexar Documento"],
        "campos_obrigatorios": {"Texto": False, "Anexar Documento": False},
        "requer_vistoria": True,
        "checklist_vistoria": ["Conferir veículo", "Conferir CNH do condutor", "Conferir mapa do circuito"],
    },
    {
        "key": "bloqueia_via",
        "pergunta": "O evento usará ou bloqueará vias/ruas municipais?",
        "descricao": "Baixe o modelo de solicitação de bloqueio de via, preencha local, data, horário, mapa/croqui do bloqueio ou desvio, assine e anexe o documento preenchido na solicitação.",
        "secretaria": "DMTRAN",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto", "Anexar Documento", "Assinatura impressa", "Assinatura gov.br"],
        "campos_obrigatorios": {"Texto": False, "Anexar Documento": False},
        "modelo_documento_nome": "Solicitação de bloqueio de via",
        "modelo_documento_url": "assets/docs/arquivos/solicitacao_de_bloqueio_de_via.pdf",
    },
    {
        "key": "tem_alimentacao",
        "pergunta": "O evento terá venda, preparo ou distribuição de alimentação?",
        "descricao": "Aciona validação da Vigilância Sanitária",
        "secretaria": "Vigilância Sanitária",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
        "requer_vistoria": True,
        "checklist_vistoria": ["Conferir higiene das instalações", "Conferir manipulação de alimentos", "Registrar fotos dos equipamentos"],
    },
    {
        "key": "precisa_ambulancia",
        "pergunta": "O evento precisará de ambulância no local?",
        "descricao": "Registra necessidade de ofício para apoio de saúde",
        "secretaria": "Vigilância Sanitária",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
    },
    {
        "key": "precisa_guarda",
        "pergunta": "Será necessária a presença da Guarda Civil Municipal?",
        "descricao": "Registra necessidade de ofício para presença da Guarda Civil Municipal",
        "secretaria": "Guarda Civil Municipal",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
    },
    {
        "key": "precisa_brigadista",
        "pergunta": "O evento exigirá brigadista contratado?",
        "descricao": "Orienta contratação sob responsabilidade do solicitante",
        "secretaria": "Desenvolvimento Econômico",
        "tipo": "Alvará de Eventos",
        "secretaria_dam": "Desenvolvimento Econômico",
        "tipos_resposta": ["Sim/Não", "Texto"],
        "campos_obrigatorios": {"Texto": False},
    },
]


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
    ]
    cpf_seed = 20000000000
    for index, (secretaria_slug, secretaria_nome, _, _) in enumerate(SECRETARIAS, start=1):
        secretaria_id = secretarias[secretaria_slug].id
        label = secretaria_nome.replace("Secretaria de ", "")
        users.extend(
            [
                {
                    "email": f"gestor_{secretaria_slug}@prefeitura.local",
                    "nome": f"Gestor {label}",
                    "cpf_cnpj": str(cpf_seed + index * 10 + 1),
                    "role_id": roles["gestor_secretaria"].id,
                    "secretaria_id": secretaria_id,
                },
                {
                    "email": f"operador_{secretaria_slug}@prefeitura.local",
                    "nome": f"Operador {label}",
                    "cpf_cnpj": str(cpf_seed + index * 10 + 2),
                    "role_id": roles["operador_secretaria"].id,
                    "secretaria_id": secretaria_id,
                },
            ]
        )

    legacy_cpf_seed = 30000000000
    for index, (secretaria_slug, legacy_users) in enumerate(LEGACY_TEST_USERS.items(), start=1):
        for offset, (email, nome, role_slug) in enumerate(legacy_users, start=1):
            users.append(
                {
                    "email": email,
                    "nome": nome,
                    "cpf_cnpj": str(legacy_cpf_seed + index * 10 + offset),
                    "role_id": roles[role_slug].id,
                    "secretaria_id": secretarias[secretaria_slug].id,
                }
            )

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


def seed_question_definitions(db):
    from src.infra.database.models import QuestionDefinitionModel

    for data in QUESTION_DEFINITIONS:
        existing = db.query(QuestionDefinitionModel).filter_by(key=data["key"]).first()
        if existing:
            fields_to_update = ["requer_vistoria", "checklist_vistoria", "prazo_resposta_dias_uteis"]
            if data["key"] == "bloqueia_via":
                fields_to_update.extend(
                    [
                        "descricao",
                        "tipos_resposta",
                        "campos_obrigatorios",
                        "modelo_documento_nome",
                        "modelo_documento_url",
                    ]
                )
            for field in fields_to_update:
                if field in data and (data["key"] == "bloqueia_via" or not getattr(existing, field, None)):
                    setattr(existing, field, data[field])
            if not getattr(existing, "prazo_resposta_dias_uteis", None):
                existing.prazo_resposta_dias_uteis = 2
            continue
        db.add(QuestionDefinitionModel(**data))


def inspection_fields(tipo_exigencia, scheduled_for=None):
    value = tipo_exigencia.lower()
    checklist = []
    if "avcb" in value:
        checklist = ["Conferir AVCB apresentado", "Conferir saídas de emergência", "Conferir extintores/sinalização"]
    elif "palco" in value or "estrutura" in value:
        checklist = ["Conferir estabilidade da estrutura", "Conferir ART", "Verificar isolamento da área"]
    elif "trio" in value:
        checklist = ["Conferir veículo", "Conferir CNH do condutor", "Conferir mapa do circuito"]
    elif "aliment" in value:
        checklist = ["Conferir higiene das instalações", "Conferir manipulação de alimentos", "Registrar fotos dos equipamentos"]
    elif "vistoria" in value:
        checklist = ["Conferir local da festa", "Conferir saídas de emergência", "Conferir alvará de funcionamento"]
    return {
        "requires_inspection": bool(checklist),
        "inspection_checklist": checklist,
        "inspection_scheduled_for": scheduled_for if checklist else None,
        "inspection_status": "agendada" if checklist and scheduled_for else "nao_agendada",
    }


def seed_permit_request(db, users, secretarias):
    existing = db.query(PermitRequestModel).filter_by(protocolo="AL-EV0001").first()
    if existing:
        return existing

    request = PermitRequestModel(
        protocolo="AL-EV0001",
        solicitante_id=users["cidadao@teste.local"].id,
        tipo="alvara_evento",
        status="em_analise",
        dam_status="nao_gerado",
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
            "data_evento": add_business_days(date.today(), 20).isoformat(),
            "endereco_evento": "Praça Central",
            "publico_estimado": 300,
            "horario_inicio": "18:00",
            "horario_termino": "23:00",
            "termo_aceite": "true",
            "anexos_informados": [
                "rg_cpf.pdf",
                "comprovante_residencia.pdf",
                "alvara_funcionamento.pdf",
            ],
        },
        respostas={
            "tem_som": True,
            "local_fixo_sem_alvara": False,
            "precisa_avcb": True,
            "tem_palco": False,
            "tem_gerador": False,
            "precisa_planta_baixa": False,
            "tem_trio_eletrico": True,
            "bloqueia_via": True,
            "tem_alimentacao": False,
            "precisa_ambulancia": False,
            "precisa_guarda": False,
            "precisa_brigadista": False,
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
                secretaria_id=secretarias["infraestrutura"].id,
                tipo_exigencia="Auto de Vistoria do Corpo de Bombeiros (AVCB)",
                **inspection_fields("Auto de Vistoria do Corpo de Bombeiros (AVCB)", date.today()),
            ),
            PermitRequirementModel(
                permit_request_id=request.id,
                secretaria_id=secretarias["dmtran"].id,
                tipo_exigencia="Vistoria de trio elétrico, CNH do motorista e mapa do circuito",
                **inspection_fields("Vistoria de trio elétrico, CNH do motorista e mapa do circuito", date.today()),
            ),
            PermitRequirementModel(
                permit_request_id=request.id,
                secretaria_id=secretarias["dmtran"].id,
                tipo_exigencia="Autorização para uso ou bloqueio de via pública",
            ),
        ]
    )
    return request


def seed_test_scenarios(db, users, secretarias):
    scenarios = [
        (
            "AL-EV0002",
            "Festival com Som e Alimentação",
            "em_analise",
            "nao_gerado",
            False,
            [("meio_ambiente", "Termo de Responsabilidade Ambiental", "aguardando_analise")],
        ),
        (
            "AL-EV0003",
            "Evento Pronto para DAM",
            "aguardando_geracao_dam",
            "pendente_prefeitura",
            False,
            [("dmtran", "Autorização para uso ou bloqueio de via pública", "aprovada")],
        ),
        (
            "AL-EV0004",
            "Evento Aguardando Pagamento",
            "aguardando_pagamento_dam",
            "gerado",
            False,
            [("infraestrutura", "Vistoria de palco/estrutura", "aprovada")],
        ),
        (
            "AL-EV0005",
            "Evento Aguardando Alvará",
            "aguardando_geracao_alvara",
            "pago",
            False,
            [("vigilancia_sanitaria", "Vistoria de equipamentos e instalações de alimentação", "aprovada")],
        ),
        (
            "AL-EV0006",
            "Evento Beneficente Autorizado",
            "autorizada",
            "isento",
            True,
            [("receita_municipal", "Conferência de declaração de evento beneficente", "aprovada")],
        ),
    ]

    for protocolo, nome_evento, status_value, dam_status, is_beneficente, requirements in scenarios:
        if db.query(PermitRequestModel).filter_by(protocolo=protocolo).first():
            continue
        request = PermitRequestModel(
            protocolo=protocolo,
            solicitante_id=users["cidadao@teste.local"].id,
            tipo="alvara_evento",
            status=status_value,
            dam_status=dam_status,
            is_beneficente=is_beneficente,
            instituicao_beneficiada="Instituição Social de Valença" if is_beneficente else None,
            dados_responsavel={
                "nome": "Maria Solicitante",
                "cpf_cnpj": "11111111111",
                "telefone": "(75) 99999-0000",
                "email": "cidadao@teste.local",
                "endereco": "Valença - BA",
            },
            dados_evento={
                "nome_evento": nome_evento,
                "data_evento": add_business_days(date.today(), 25).isoformat(),
                "endereco_evento": "Orla de Valença",
                "publico_estimado": 500,
                "horario_inicio": "17:00",
                "horario_termino": "23:30",
                "termo_aceite": "true",
                "anexos_informados": ["rg_cpf.pdf", "comprovante_residencia.pdf", "alvara_funcionamento.pdf"],
            },
            respostas={"tem_som": True, "tem_alimentacao": True},
        )
        db.add(request)
        db.flush()
        for secretaria_slug, tipo_exigencia, requirement_status in requirements:
            fields = inspection_fields(
                tipo_exigencia,
                date.today() if requirement_status != "aprovada" else add_business_days(date.today(), -1),
            )
            if requirement_status == "aprovada" and fields["requires_inspection"]:
                fields["inspection_status"] = "aprovada"
            db.add(
                PermitRequirementModel(
                    permit_request_id=request.id,
                    secretaria_id=secretarias[secretaria_slug].id,
                    tipo_exigencia=tipo_exigencia,
                    status=requirement_status,
                    **fields,
                )
            )
        if dam_status in {"gerado", "pago"}:
            db.add(
                AttachmentModel(
                    permit_request_id=request.id,
                    tipo_documento="dam",
                    nome_arquivo=f"dam_{protocolo}.pdf",
                    arquivo_url=f"/uploads/{protocolo}/dam.pdf",
                    mime_type="application/pdf",
                    tamanho_bytes=120000,
                )
            )
        if dam_status == "pago":
            db.add(
                AttachmentModel(
                    permit_request_id=request.id,
                    tipo_documento="comprovante_pagamento_dam",
                    nome_arquivo=f"comprovante_{protocolo}.pdf",
                    arquivo_url=f"/uploads/{protocolo}/comprovante.pdf",
                    mime_type="application/pdf",
                    tamanho_bytes=90000,
                )
            )
        if status_value == "autorizada":
            token = create_event_credential_token(protocolo, request.id)
            db.add(
                AttachmentModel(
                    permit_request_id=request.id,
                    tipo_documento="alvara_evento",
                    nome_arquivo=f"alvara_{protocolo}.pdf",
                    arquivo_url=f"/uploads/{protocolo}/alvara.pdf",
                    mime_type="application/pdf",
                    tamanho_bytes=140000,
                )
            )
            db.add(
                EventCredentialModel(
                    permit_request_id=request.id,
                    codigo_publico=protocolo,
                    token_hash=hash_token(token),
                    status="ativa",
                    valid_from=datetime.now(timezone.utc),
                    valid_until=datetime.now(timezone.utc) + timedelta(days=30),
                    issued_by=users["admin@prefeitura.local"].id,
                )
            )


def seed_home_content(db, users):
    admin_id = users["admin@prefeitura.local"].id
    cards = [
        (
            "prefeitura",
            "Central de Eventos",
            "Solicite o alvará de evento em um único fluxo digital, com acompanhamento das secretarias responsáveis.",
            "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&w=1200&q=80",
            1,
        ),
        (
            "prefeitura",
            "Atendimento ao cidadão",
            "A Prefeitura de Valença reúne serviços municipais para facilitar o acesso de pessoas físicas e jurídicas.",
            "https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1200&q=80",
            2,
        ),
        (
            "desenvolvimento_economico",
            "Desenvolvimento Econômico",
            "A Secretaria coordena a Central de Eventos e acompanha a emissão final da autorização municipal.",
            "https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80",
            1,
        ),
        (
            "meio_ambiente",
            "Responsabilidade ambiental",
            "Eventos com som passam pela análise ambiental para orientar limites e responsabilidades.",
            "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=80",
            1,
        ),
        (
            "dmtran",
            "Mobilidade e vias públicas",
            "Bloqueios, desvios e trio elétrico são avaliados pelo DMTRAN para organizar o trânsito com segurança.",
            "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=1200&q=80",
            1,
        ),
    ]
    for scope, title, body, image_url, display_order in cards:
        existing = (
            db.query(HomeContentCardModel)
            .filter(HomeContentCardModel.scope == scope, HomeContentCardModel.title == title)
            .first()
        )
        if existing:
            continue
        db.add(
            HomeContentCardModel(
                scope=scope,
                title=title,
                body=body,
                image_url=image_url,
                display_order=display_order,
                is_active=True,
                created_by=admin_id,
                updated_by=admin_id,
            )
        )


def seed_public_ranges(db):
    ranges = [
        ("10 a 50 pessoas", 10, 50, 3),
        ("51 a 100 pessoas", 51, 100, 5),
        ("101 a 300 pessoas", 101, 300, 10),
        ("301 a 500 pessoas", 301, 500, 15),
        ("Acima de 500 pessoas", 501, 100000, 20),
    ]
    for label, min_publico, max_publico, prazo_dias_uteis in ranges:
        existing = (
            db.query(EventPublicRangeModel)
            .filter(EventPublicRangeModel.min_publico == min_publico, EventPublicRangeModel.max_publico == max_publico)
            .first()
        )
        if existing:
            existing.label = label
            existing.prazo_dias_uteis = prazo_dias_uteis
            existing.is_active = True
            continue
        db.add(
            EventPublicRangeModel(
                label=label,
                min_publico=min_publico,
                max_publico=max_publico,
                prazo_dias_uteis=prazo_dias_uteis,
                is_active=True,
            )
        )


def add_business_days(start_date, business_days):
    current_date = start_date
    added_days = 0
    while added_days < business_days:
        current_date += timedelta(days=1)
        if current_date.weekday() < 5:
            added_days += 1
    return current_date


def main():
    reset = "--reset" in sys.argv
    if reset:
        Base.metadata.drop_all(bind=engine)
    create_tables()
    ensure_secretaria_columns()
    ensure_question_definition_columns()
    ensure_event_credential_columns()
    ensure_requirement_inspection_columns()
    db = SessionLocal()
    try:
        roles = seed_roles(db)
        seed_permissions(db, roles)
        secretarias = seed_secretarias(db)
        users = seed_users(db, roles, secretarias)
        seed_question_definitions(db)
        seed_public_ranges(db)
        seed_permit_request(db, users, secretarias)
        seed_test_scenarios(db, users, secretarias)
        seed_home_content(db, users)
        db.commit()
        print("Seed executado com sucesso.")
        if reset:
            print("Banco zerado e recriado com dados de teste.")
        print("Usuários de teste: admin@prefeitura.local, cidadao@teste.local")
        print("Cada secretaria possui gestor_<secretaria>@prefeitura.local e operador_<secretaria>@prefeitura.local")
        print("Senha padrão: 123456")
    finally:
        db.close()


if __name__ == "__main__":
    main()
