# Plano de publicação do MVP

Data alvo: segunda-feira, 31/08/2026.

## Estratégia de branches

- `main`: manter limpa, recebendo somente merge aprovado depois da homologação.
- `develop`: branch de integração das entregas aprovadas para o MVP.
- `mvp`: branch usada no servidor de homologação/MVP.
- `feat/*` e `fix/*`: branches de trabalho para novas telas e correções.

Fluxo recomendado:

1. Finalizar alterações na branch de trabalho.
2. Rodar validações locais: `flutter analyze`, build web e compilação do backend.
3. Criar PR da branch de trabalho para `develop`.
4. Atualizar `mvp` a partir de `develop` para subir a homologação.
5. Homologar o sistema pela URL de staging.
6. Abrir PR de `mvp` para `main`.
7. Fazer tag `v0.1.0-mvp` após o merge em `main`.

## Checklist antes do merge para main

- Login cidadão por CPF/CNPJ.
- Login interno por e-mail institucional.
- Recarregar a página sem perder sessão.
- Cadastro cidadão com foto e comprovante de residência.
- Criação de solicitação de alvará de evento.
- Bloqueio de data antes do prazo mínimo.
- Seleção de tipo de evento e documentos necessários.
- Perguntas condicionais, inclusive rota do evento.
- Fila interna por secretaria.
- Visualização de respostas e anexos do cidadão.
- Agendamento, confirmação e reagendamento de vistoria.
- Relatórios por período, ano, tipo, bairro e mês.
- Emissão/visualização de autorização final e QR Code.
- Seed de homologação com usuários/solicitações históricas importados da planilha privada, sem versionar CPF/CNPJ no Git.
- Seed padrão mantido com solicitações em cada status do fluxo do MVP.

## Onde subir primeiro

Para este MVP, a opção mais direta é uma VPS simples rodando Docker Compose.

Motivo: o projeto já possui `docker-compose.yml` com três serviços: `web` em Nginx, `api` FastAPI e `mysql`. Isso encaixa melhor em uma VPS ou Lightsail Instance do que em hospedagem Node.js automática.

### Hostinger

O tutorial da Hostinger para apps criados com Codex foca em Hospedagem Node.js, detecção por `package.json`, deploy via GitHub/ZIP e configuração de variáveis no hPanel: https://www.hostinger.com/br/tutoriais/como-publicar-app-codex/

Para este sistema, Hostinger só é boa se usarmos VPS com Docker. A hospedagem Node.js não é o caminho natural porque a API é Python/FastAPI e o banco é MySQL via container.

### AWS Lightsail

O Lightsail tem planos previsíveis de VPS Linux a partir de valores baixos e opção de avaliação gratuita para planos elegíveis: https://aws.amazon.com/lightsail/pricing/ e https://aws.amazon.com/free/compute/lightsail/

Também existe Lightsail Containers, mas ele cobra serviço de container continuamente e o banco gerenciado é cobrado à parte: https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-container-services.html

Guia operacional do caminho escolhido para o MVP: `docs/aws_lightsail_mvp.md`.

Recomendação para segunda-feira:

- Mais simples: VPS Hostinger ou Lightsail Instance Linux com Docker Compose.
- Mais alinhado com AWS: Lightsail Instance de 2 GB ou 4 GB RAM para web + API + MySQL no mesmo host no MVP.
- Evitar no primeiro deploy: Lightsail Containers + database separado, porque aumenta configuração e custo inicial.

## Variáveis de produção

Configurar no servidor:

- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `MYSQL_ROOT_PASSWORD`
- `DATABASE_URL`
- `SECRET_KEY`
- `PUBLIC_BASE_URL`
- `SDE_EMAIL`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USE_TLS`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM`
- `PREFEITURA_LOGO_URL`
- `HISTORICAL_EVENTS_XLSX_PATH`

## Comandos-base no servidor

```bash
git clone <repo>
cd permit_web_app
git checkout mvp
cp .env.homologacao.example .env
docker compose up -d --build
docker compose ps
```

Após subir, validar:

```bash
curl http://localhost:8000/health
curl http://localhost:8080
```
