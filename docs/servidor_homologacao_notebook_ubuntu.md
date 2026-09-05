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

Para carregar usuários e solicitações reais da planilha histórica, copie a planilha para uma pasta privada, fora do Git:

```bash
mkdir -p permit_system/private
cp "/caminho/seguro/Planilha_de_solicitacao_de_eventos.xlsx" permit_system/private/Planilha_de_solicitacao_de_eventos.xlsx
```

No `.env`, mantenha:

```bash
HISTORICAL_EVENTS_XLSX_PATH=/app/private/Planilha_de_solicitacao_de_eventos.xlsx
```

Usuários importados da planilha entram como cidadãos. O login inicial é o CPF/CNPJ e a senha inicial também é o CPF/CNPJ, somente com números. No primeiro acesso, o sistema obriga a troca de senha.

O seed padrão do MVP continua criando solicitações de teste em cada status. As solicitações importadas da planilha entram como histórico aprovado quando a data do evento já passou; se uma nova planilha trouxer evento futuro, a solicitação entra em análise.

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

## Teste com servicevca.zapto.org

Dados informados para o teste:

- IP público: `170.239.37.184`
- Domínio: `servicevca.zapto.org`
- IP local da máquina: `192.168.0.13`

O DNS já deve apontar `servicevca.zapto.org` para `170.239.37.184`.

No roteador da rede, crie redirecionamento de portas para a máquina `192.168.0.13`:

- Porta externa `80` TCP para `192.168.0.13:80`
- Porta externa `443` TCP para `192.168.0.13:443`

Não redirecione MySQL para internet. Também não precisa redirecionar a porta `8000`, pois o Caddy repassa `/api` para o backend dentro da rede Docker.

No servidor, use o env específico:

```bash
cp .env.servicevca.example .env
nano .env
```

Troque pelo menos `SECRET_KEY`, `MYSQL_PASSWORD` e `MYSQL_ROOT_PASSWORD`.

Suba os containers:

```bash
docker compose --profile https up -d --build
docker compose ps
curl -I http://127.0.0.1:8080
curl http://127.0.0.1:8000/health
```

Valide pelo domínio:

```bash
curl -I https://servicevca.zapto.org
curl https://servicevca.zapto.org/api/health
```

O Caddy roda como container no próprio Compose. A instalação manual abaixo é opcional, caso algum dia prefira usar Caddy direto no Ubuntu em vez do container.

Instale o Caddy no Ubuntu:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

Configure o proxy:

```bash
sudo cp docs/Caddyfile.servicevca.example /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy --no-pager
```

Valide de fora da rede ou pelo 4G:

```bash
curl -I https://servicevca.zapto.org
curl https://servicevca.zapto.org/api/health
```

Se `curl http://servicevca.zapto.org` der timeout, o problema está antes do sistema: porta do roteador, firewall do Ubuntu, CGNAT da operadora ou serviço Caddy ainda não escutando.

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
