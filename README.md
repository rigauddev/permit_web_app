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

Usuários de teste criados automaticamente no container da API:

- `admin@prefeitura.local` / `123456`
- `cidadao@teste.local` / `123456`
- `receita@prefeitura.local` / `123456`
- `meioambiente@prefeitura.local` / `123456`
- `dmtran@prefeitura.local` / `123456`
- `gestor@prefeitura.local` / `123456`

O banco local do Docker usa SQLite persistido no volume `permit_system_data`. Para reiniciar o ambiente com banco limpo:

```bash
docker compose down -v
docker compose up --build
```

Para validar os containers:

```bash
docker compose ps
curl http://localhost:8000/health
```

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

## 🧱 Estrutura do projeto

core/: temas, rotas e utilitários globais

data/: modelos compartilhados

features/: organização por funcionalidades

presentation/: widgets reutilizáveis
