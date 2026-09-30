#!/usr/bin/env bash
set -euo pipefail

# Executa esta branch local contra a API de homologação e expõe o atalho
# temporário para a página administrativa. Não use estas flags em produção.
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://servicevca.zapto.org/api \
  --dart-define=SHOW_ADMIN_LOGIN=true
