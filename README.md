# Projeto Flutter - Serviços

## ✅ Requisitos

- Flutter 3.x
- Docker
- Android Studio ou VS Code com Dart/Flutter plugin

## 🚀 Rodando o Projeto com Docker

1. Certifique-se de que o Docker está instalado e rodando.
2. No terminal, execute:

```bash
docker build -t alvara_app .
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