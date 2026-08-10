# Projeto Flutter - Serviços

## ✅ Requisitos

- Flutter 3.x
- Docker
- Android Studio ou VS Code com Dart/Flutter plugin

## 🚀 Rodando o projeto com Docker

1. Certifique-se de que o Docker está instalado e rodando.
2. Opcionalmente, crie o `.env` do compose:

```bash
cp .env.docker.example .env
```

3. Suba API e frontend:

```bash
docker compose up --build
```

Aplicação web: `http://localhost:8080`

API: `http://localhost:8000`

MySQL local do Docker: `localhost:3307`

Usuários de teste criados automaticamente no container da API:

- `admin@prefeitura.local` / `123456`
- `cidadao@teste.local` / `123456`
- `receita@prefeitura.local` / `123456`
- `meioambiente@prefeitura.local` / `123456`
- `dmtran@prefeitura.local` / `123456`
- `gestor@prefeitura.local` / `123456`

O banco local do Docker usa MySQL 8 persistido no volume `permit_mysql_data`. Para reiniciar o ambiente com banco limpo:

```bash
docker compose down -v
docker compose up --build
```

Para validar os containers:

```bash
docker compose ps
curl http://localhost:8000/health
```

Credenciais padrão do MySQL no Docker:

- database: `permit_system`
- user: `permit_user`
- password: `permit_password`
- root password: `permit_root_password`

Para rodar somente o frontend web estático:

```bash
docker build --build-arg API_BASE_URL=http://localhost:8000 -t alvara_app .
docker run -p 8080:80 alvara_app
```

## 🔧 Desenvolvimento local

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

### Teste em device físico

No celular, `localhost` aponta para o próprio aparelho. Para testar com a API rodando na sua máquina, use o IP local do computador na mesma rede Wi-Fi.

1. Suba a API:

```bash
docker compose up -d api
```

2. Descubra o IP da máquina:

```bash
ipconfig getifaddr en0
```

3. Rode no device informando a URL da API:

```bash
flutter devices
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://SEU_IP:8000
```

Exemplo:

```bash
flutter run -d 00008110-001C195E0E91801E --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

Para Android em modo debug, o app permite HTTP local. Para homologação/produção e publicação nas lojas, use domínio com HTTPS.

## 🧱 Estrutura do projeto

core/: temas, rotas e utilitários globais

data/: modelos compartilhados

features/: organização por funcionalidades

presentation/: widgets reutilizáveis
