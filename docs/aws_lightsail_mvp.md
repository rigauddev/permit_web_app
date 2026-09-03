# Publicação do MVP na AWS Lightsail

Objetivo: subir somente o serviço de Alvará de Evento em uma instância Linux do AWS Lightsail, usando Docker Compose para web Flutter, API FastAPI e MySQL.

## Fontes oficiais consultadas

- IP estático no Lightsail: https://docs.aws.amazon.com/lightsail/latest/userguide/lightsail-create-static-ip.html
- Firewall do Lightsail: https://docs.aws.amazon.com/lightsail/latest/userguide/understanding-firewall-and-port-mappings-in-amazon-lightsail.html
- Certificados SSL/TLS no Lightsail: https://docs.aws.amazon.com/lightsail/latest/userguide/understanding-tls-ssl-certificates-in-lightsail-https.html
- FAQ do Lightsail: https://aws.amazon.com/lightsail/faq/

## Tamanho inicial sugerido

Para homologação e MVP com poucas secretarias em teste:

- Mínimo: 2 GB RAM.
- Recomendado: 4 GB RAM, 2 vCPU, 80 GB SSD ou superior.

O projeto sobe três containers no mesmo host. Para o MVP isso simplifica custo e operação. Depois da validação, o banco pode ser separado em um serviço gerenciado.

## Criar a instância

1. Acesse o console do Lightsail.
2. Região sugerida: `us-east-1`, se for a região escolhida no link informado.
3. Plataforma: Linux/Unix.
4. Blueprint: Ubuntu LTS.
5. Plano: 4 GB RAM para uma margem melhor.
6. Nome sugerido: `permit-mvp-alvara`.
7. Crie a instância.

## Configurar rede

No Lightsail, crie e anexe um IP estático na mesma região da instância. A documentação oficial recomenda isso porque o IP público dinâmico muda quando a instância é parada e iniciada novamente.

No firewall do Lightsail, mantenha:

- `22/tcp`: SSH, idealmente restrito ao IP de administração.
- `80/tcp`: HTTP.
- `443/tcp`: HTTPS.

Não exponha a porta do MySQL publicamente. No Docker Compose atual a porta local é `3307`, mas o firewall do Lightsail deve continuar fechado para essa porta.

## Preparar o Ubuntu

```bash
sudo apt update
sudo apt install -y git curl ca-certificates gnupg openssh-server
sudo systemctl enable --now ssh
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Saia e entre novamente no SSH para o grupo `docker` ser aplicado.

Validar:

```bash
docker --version
docker compose version
git --version
```

## Subir o projeto

```bash
git clone https://github.com/rigauddev/permit_web_app.git
cd permit_web_app
git checkout mvp
cp .env.homologacao.example .env
nano .env
```

Configure no `.env`:

```env
WEB_PORT=8080
API_PORT=8000
MYSQL_PORT=3307
API_BASE_URL=https://api.seu-dominio.com
PUBLIC_BASE_URL=https://app.seu-dominio.com
SECRET_KEY=troque-por-uma-chave-grande
MYSQL_DATABASE=permit_system_mvp
MYSQL_USER=permit_user_mvp
MYSQL_PASSWORD=troque-esta-senha
MYSQL_ROOT_PASSWORD=troque-esta-senha-root
DATABASE_URL=mysql+mysqlconnector://permit_user_mvp:troque-esta-senha@mysql:3306/permit_system_mvp
HISTORICAL_EVENTS_XLSX_PATH=/app/private/Planilha_de_solicitacao_de_eventos.xlsx
```

Copie a planilha histórica para a pasta privada do servidor:

```bash
mkdir -p permit_system/private
scp "Planilha_de_solicitacao_de_eventos.xlsx" ubuntu@IP_DA_INSTANCIA:/home/ubuntu/permit_web_app/permit_system/private/Planilha_de_solicitacao_de_eventos.xlsx
```

Essa pasta está ignorada pelo Git para evitar versionar CPF/CNPJ e dados pessoais.

Subir:

```bash
docker compose up -d --build
docker compose ps
```

Validar localmente na instância:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8080
```

## HTTPS e domínio

Opção simples para o MVP:

- Usar Caddy ou Nginx no host como proxy reverso.
- Apontar `app.seu-dominio.com` para `127.0.0.1:8080`.
- Apontar `api.seu-dominio.com` para `127.0.0.1:8000`.
- Abrir no Lightsail somente `80` e `443`.

Se usar certificado do próprio Lightsail ou outro caminho AWS, seguir a documentação oficial de SSL/TLS do Lightsail. Se usar Caddy, ele emite HTTPS automaticamente quando o DNS já aponta para o IP da instância.

## Seed histórico

Ao iniciar, o seed procura a planilha em `HISTORICAL_EVENTS_XLSX_PATH`.

Fluxo aplicado:

1. Lê as abas históricas `2025` e `2026`.
2. Cadastra cidadãos por CPF/CNPJ.
3. Cria solicitações associadas ao CPF/CNPJ do solicitante.
4. Mantém o seed padrão do MVP com solicitações em cada status de teste.
5. Marca solicitações históricas com data já realizada como `autorizada`.
6. Se houver solicitação histórica com data futura em nova planilha, ela entra em `em_analise`.
7. Define login inicial e senha inicial como CPF/CNPJ somente com números para cidadãos criados pela importação.
8. Marca `must_change_password=true`, obrigando troca de senha no primeiro acesso.

## Atualização do MVP

```bash
cd permit_web_app
git fetch origin
git checkout mvp
git pull origin mvp
docker compose up -d --build
docker compose ps
```

## Backup mínimo

Antes de atualizar ou reiniciar com mudança grande:

```bash
docker compose exec mysql mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > backup_mvp.sql
```

Guarde o arquivo fora da instância ou em armazenamento privado.
