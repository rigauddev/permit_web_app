# permit_system

Este é um projeto de backend FastAPI para um sistema de gerenciamento de permissões. Ele fornece funcionalidades para autenticação de usuários, gerenciamento de entidades, permissões, formulários, solicitações e avaliações.

## Tecnologias Utilizadas

* FastAPI
* Uvicorn
* Python-jose\[cryptography]
* Passlib\[bcrypt]
* PyOTP
* MySQL
* MongoDB
* SQLAlchemy
* Pydantic
* Python-dotenv

## Pré-requisitos

* Python 3.7+
* MySQL
* MongoDB

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
    MYSQL_HOST=localhost
    MYSQL_USER=seu_usuario
    MYSQL_PASSWORD=sua_senha
    MYSQL_DATABASE=alvara_db
    MONGO_HOST=localhost
    MONGO_PORT=27017
    MONGO_DATABASE=alvara_mongo
    OTP_SECRET_KEY=sua_chave_secreta
    SMTP_SERVER=smtp.gmail.com
    SMTP_PORT=465
    SMTP_EMAIL=seu_email@gmail.com
    SMTP_PASSWORD=sua_senha
    ```

    Substitua os valores pelos seus dados de configuração.

5. Crie as tabelas no banco de dados MySQL:

    Execute o script de criação de tabelas no módulo de banco em `permit_system/src/infra/database/`.

## Execução

Para executar a aplicação, execute o seguinte comando:

```bash
uvicorn main:app --reload
```
