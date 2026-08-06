# Projeto Flutter - Serviços

## ✅ Requisitos

- Flutter 3.x
- Docker
- Android Studio ou VS Code com Dart/Flutter plugin

## 🚀 Rodando o Projeto com Docker

1. Certifique-se de que o Docker está instalado e rodando.
2. No terminal, execute:

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

Para rodar somente o frontend web estático:

```bash
docker build --build-arg API_BASE_URL=http://localhost:8000 -t alvara_app .
docker run -p 8080:80 alvara_app
```

 ## 🔧 Desenvolvimento Local


 flutter pub get
 lutter run -d chrome

 ## 🧱 Estrutura do Projeto

core/: temas, rotas e utilitários globais

data/: modelos compartilhados

features/: organização por funcionalidades

presentation/: widgets reutilizáveis
