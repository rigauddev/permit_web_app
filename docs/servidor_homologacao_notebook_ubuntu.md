# Servidor de homologação no notebook Ubuntu

Objetivo: usar o notebook Ubuntu como servidor de homologação/MVP para Flutter Web, FastAPI e MySQL em Docker.

Configuração informada: i7 12ª geração, 16 GB RAM e 500 GB. É suficiente para homologação interna das secretarias.

## Fluxo de branches

- `mvp`: branch que roda no servidor de homologação.
- `develop`: branch de integração das entregas aprovadas para o MVP.
- `main`: branch limpa, recebendo merge somente depois da validação final.

Fluxo recomendado:

1. Desenvolver e testar em branches de trabalho.
2. Fazer merge para `develop`.
3. Atualizar `mvp` a partir de `develop`.
4. Subir o servidor usando a branch `mvp`.
5. Depois da homologação, fazer merge de `mvp` para `main` e criar tag.

## Instalação base no Ubuntu

```bash
sudo apt update
sudo apt install -y git curl ca-certificates gnupg openssh-server
sudo systemctl enable --now ssh
```

Instalar Docker:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Depois saia e entre novamente no usuário do Ubuntu para o grupo `docker` ser aplicado.

Validar:

```bash
docker --version
docker compose version
git --version
```

## Clonar e subir o sistema

```bash
git clone https://github.com/rigauddev/permit_web_app.git
cd permit_web_app
git checkout mvp
cp .env.homologacao.example .env
nano .env
docker compose up -d --build
docker compose ps
```

Validar serviços:

```bash
curl http://localhost:8000/health
curl http://localhost:8080
```

## Domínio e HTTPS

Para homologação, o caminho mais simples é usar Cloudflare Tunnel ou Tailscale Funnel. Assim não precisa abrir portas no roteador nem depender de IP público fixo.

Com IP público fixo, apontar DNS para o IP do notebook e usar Caddy ou Nginx como proxy reverso para:

- Web: `http://127.0.0.1:8080`
- API: `http://127.0.0.1:8000`

## Atualizar homologação

```bash
cd permit_web_app
git fetch origin
git checkout mvp
git pull origin mvp
docker compose up -d --build
docker compose ps
```

## Gerar APK para teste interno

Use a URL pública da API de homologação:

```bash
flutter clean
flutter pub get
flutter build apk --dart-define=API_BASE_URL=https://homologacao-api.seu-dominio.com
```

O APK final fica em:

```bash
build/app/outputs/flutter-apk/app-release.apk
```

## Cuidados mínimos

- Trocar todas as senhas do `.env`.
- Fazer backup periódico do volume `permit_mysql_data`.
- Não expor a porta do MySQL na internet.
- Manter `main` sem deploy automático até o MVP ser aprovado.
- Rodar `flutter analyze` e compilação do backend antes de atualizar `mvp`.
