# permit_system

Este é o backend FastAPI do sistema municipal de alvará de eventos. Ele fornece autenticação, MFA, usuários, permissões, secretarias, solicitações, exigências e anexos.

## Tecnologias Utilizadas

* FastAPI
* Uvicorn
* Python-jose\[cryptography]
* Passlib\[bcrypt]
* PyOTP
* MySQL no desenvolvimento local via Docker
* Banco relacional compatível com SQLAlchemy em homologação/produção
* SQLAlchemy
* Pydantic
* Python-dotenv

## Pré-requisitos

* Python 3.12+
* SQLite para desenvolvimento local ou outro banco compatível com SQLAlchemy via `DATABASE_URL`

## Instalação

1. Clone o repositório:
    ```bash
    git clone <seu_repositorio>
    cd permit_web_app/permit_system
    ```

2. Crie um ambiente virtual (recomendado):
- Comando para criar o ambiente:
        ```python3 -m venv .venv ```

    - Comando para ativar ambiente:
        ```source .venv/bin/activate ```

    Após a execução do comandos é só seguir os proximos passos.

- Instalar as dependencias do projeto
```pip3 install -r requirements.txt```

4. Configure as variáveis de ambiente:

    Crie um arquivo `.env` na raiz do projeto e adicione as seguintes variáveis:
    ```env
    DATABASE_URL=mysql+mysqlconnector://permit_user:permit_password@localhost:3307/permit_system
    SECRET_KEY=troque-esta-chave-em-producao
    JWT_ALGORITHM=HS256
    ACCESS_TOKEN_EXPIRE_MINUTES=480
    ```

    Substitua os valores pelos seus dados de configuração.

5. Crie as tabelas e dados iniciais:

    ```bash
    python scripts/seed.py
    ```

## Execução

Para executar a aplicação, execute o seguinte comando:

```bash
uvicorn main:app --reload
```

## Desenvolvimento local com seeds

O backend usa `DATABASE_URL`. No Docker Compose do projeto, o padrão é MySQL 8 com o banco `permit_system`.

```bash
cp .env.example .env
pip install -r requirements.txt
python scripts/seed.py
uvicorn main:app --reload
```

Usuários de teste criados pelo seed:

- `admin@prefeitura.local`
- `cidadao@teste.local`
- `receita@prefeitura.local`
- `meioambiente@prefeitura.local`
- `dmtran@prefeitura.local`
- `gestor@prefeitura.local`

Senha padrão: `123456`.

### Cenário de homologação do Acesso à Orla

O mesmo comando cria e atualiza um cenário ativo para a Orla de Guaibim:

- `admin@prefeitura.local` — administrador do sistema;
- `turista@orla.teste.local` — turista com a placa `GUA1B26` autorizada;
- `pousada@orla.teste.local` — Pousada Mar de Guaibim, aprovada na área da Orla;
- `operador_dmtran@prefeitura.local` — operador de fiscalização do DMTRAN, credencial `DMTRAN-ORLA-OPERADOR`;
- `gestor_dmtran@prefeitura.local` — gestão do DMTRAN, credencial `DMTRAN-ORLA-GESTOR`.

A senha desses usuários é `123456`. O seed deixa ativo apenas o serviço **Acesso à Orla** e pode ser executado mais de uma vez sem duplicar o cenário.

Para carregar apenas os dados necessários para a homologação da Orla, sem importar solicitações históricas de Alvarás, execute:

```bash
python scripts/seed_orla.py
```
