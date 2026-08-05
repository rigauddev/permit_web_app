# Documentação Interna e Técnica

## Estado atual do código

O projeto está dividido em:

- `permit_app/permit_app/permit_web_app`: frontend Flutter para web/mobile.
- `permit_system`: backend Python/FastAPI planejado, mas ainda sem implementação funcional. O arquivo `permit_system/main.py` contém apenas `1`.

O frontend já possui telas de login, cadastro, home, serviços da Receita Municipal, dashboard de alvarás e formulário de solicitação. Grande parte dos dados ainda está mockada no app.

## Tecnologias identificadas

Frontend:

- Flutter/Dart.
- Riverpod/Hooks Riverpod.
- Shared Preferences e Flutter Secure Storage.
- File Picker para anexos.
- HTTP, ainda sem camada de API consolidada.

Backend planejado:

- FastAPI.
- MySQL.
- MongoDB.
- SQLAlchemy/Pydantic.
- JWT/MFA, ainda não implementados de ponta a ponta.

## Arquivos principais do Flutter

- `lib/main.dart`: inicialização, tema, rotas estáticas e `onGenerateRoute`.
- `lib/core/routes/app_routes.dart`: rotas dinâmicas do dashboard e solicitação.
- `lib/core/auth_service.dart`: autenticação mockada, usuários de teste e MFA fixo.
- `lib/features/services/receita_municipal/ui/receita_municipal_services_page.dart`: entrada do serviço de alvará e mocks de perguntas/formulários.
- `lib/presentation/pages/user_alvara_dashboard.dart`: lista solicitações e detalhes por secretaria.
- `lib/features/permit_request/pages/permit_request_page.dart`: tela do fluxo de solicitação.
- `lib/features/permit_request/pages/permit_request_form_builder.dart`: campos por etapa.
- `lib/features/permit_request/controller/permit_request_controller.dart`: estado e submissão mockada.

## Riscos técnicos críticos para o MVP

1. Backend não funcional.
   O app ainda depende de mocks locais; sem backend não há persistência real, autenticação segura, upload real nem workflow interno.

2. Autenticação insegura.
   Existem usuários mockados, senha `123456`, hash SHA-256 simples no cliente e MFA fixo `123456`. Isso não pode ir para produção como autenticação real.

3. Estado do formulário sobrescreve dados.
   `updateBasicInfo` e `updateEventInfo` usam chaves negativas repetidas em `answers`. Exemplo: endereço, e-mail, nome/data/endereço do evento podem colidir.

4. Perguntas condicionais ainda não são realmente condicionais.
   O app exibe perguntas, mas não monta automaticamente as pendências por secretaria com base nas respostas.

5. Rotas e permissões ainda são frágeis.
   O Drawer mostra menus por `userType`, mas não há guarda central de rota nem validação no backend.

6. Upload de documentos é local.
   O File Picker seleciona arquivos, mas não faz persistência, validação de tipo/tamanho ou envio.

7. Geração de autorização/DAM não existe.
   Para o MVP, o sistema deve gerar autorização com status "DAM pendente na Receita Municipal" ou "Isento por declaração beneficente".

## Modelo de domínio recomendado

Entidades mínimas:

- `User`: id, tipo_pessoa, nome/razao_social, cpf_cnpj, email, telefone, senha_hash, status.
- `Role`: admin, gestor_secretaria, operador_secretaria, cidadao.
- `Secretaria`: id, nome, slug, ativa.
- `PermitRequest`: id, protocolo, solicitante_id, tipo, status, dados_responsavel, dados_evento, is_beneficente, dam_status, created_at.
- `PermitRequirement`: id, request_id, secretaria_id, tipo_exigencia, status, observacoes.
- `Attachment`: id, request_id, requirement_id opcional, tipo_documento, arquivo_url, mime_type, tamanho.
- `Comment`: id, request_id, requirement_id, author_id, mensagem, created_at.
- `AuditLog`: ator, ação, entidade, data/hora, metadados.

## Status recomendados

Solicitação:

- `rascunho`
- `enviada`
- `em_analise`
- `pendente_correcao`
- `aprovacoes_concluidas`
- `dam_pendente`
- `isenta_dam`
- `autorizada`
- `indeferida`
- `cancelada`

Exigência por secretaria:

- `nao_aplicavel`
- `aguardando_analise`
- `pendente_documento`
- `aprovada`
- `recusada`

DAM:

- `nao_gerado`
- `pendente_prefeitura`
- `isento`
- `pago`

## Contratos mínimos de API para o MVP

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/email-verifications`
- `POST /auth/email-verifications/confirm`
- `POST /auth/mfa/generate`
- `POST /auth/mfa/verify`
- `GET /me`
- `GET /permit-types`
- `GET /permit-types/{id}/questions`
- `POST /permit-requests`
- `GET /permit-requests`
- `GET /permit-requests/{id}`
- `POST /permit-requests/{id}/attachments`
- `POST /permit-requests/{id}/comments`
- `PATCH /requirements/{id}/status`
- `POST /permit-requests/{id}/issue-authorization`

## Segurança mínima antes de produção

- Senha com hash no backend usando bcrypt/argon2.
- JWT ou sessão segura emitida pelo backend.
- Remover usuários mockados de produção.
- Auto-cadastro de cidadão deve validar e-mail antes de liberar o formulário.
- O tipo de usuário deve ser definido pelo `role` vindo do backend/JWT, nunca pela escolha visual da tela de login.
- RBAC validado no backend, não apenas no Flutter.
- Validação de CPF/CNPJ, e-mail, telefone e data.
- Limite de tamanho e tipo para anexos.
- Registro de auditoria em ações internas.
- HTTPS obrigatório no ambiente publicado.
- Segredos somente em `.env`, nunca no repositório.

## Critério de pronto do MVP

O MVP está pronto quando:

- Usuário consegue se cadastrar e entrar.
- Usuário consegue solicitar alvará de evento.
- Sistema mostra exigências por resposta.
- Sistema salva solicitação e anexos.
- Operador interno vê apenas solicitações da sua secretaria.
- Operador aprova, recusa ou pede correção com observação.
- Cidadão acompanha status.
- Admin gerencia perguntas/secretarias/permissões básicas.
- Autorização final é gerada com indicação de DAM pendente ou isenção.
