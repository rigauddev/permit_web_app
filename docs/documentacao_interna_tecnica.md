# Documentação Interna e Técnica

## Estado atual do código

O projeto está dividido em:

- `permit_app/permit_app/permit_web_app`: frontend Flutter para web/mobile.
- `permit_system`: backend Python/FastAPI com autenticação, MFA por e-mail, RBAC básico, usuários/secretarias, solicitações de alvará, exigências por secretaria e seeds.

O frontend possui telas de login, cadastro com validação prévia de e-mail, home por perfil, serviço único do MVP, dashboard de alvarás e formulário de solicitação com revisão antes do envio. O caminho principal de autenticação e solicitações usa a API HTTP.

## Tecnologias identificadas

Frontend:

- Flutter/Dart.
- Riverpod/Hooks Riverpod.
- Shared Preferences e Flutter Secure Storage.
- File Picker para anexos.
- HTTP com camadas `AuthService` e `PermitApiService`.

Backend:

- FastAPI.
- MySQL.
- SQLAlchemy/Pydantic.
- JWT/MFA por e-mail.

## Arquivos principais do Flutter

- `lib/main.dart`: inicialização, tema, rotas estáticas e `onGenerateRoute`.
- `lib/core/routes/app_routes.dart`: rotas dinâmicas do dashboard e solicitação.
- `lib/core/auth_service.dart`: login, geração/verificação de MFA, validação de e-mail e cadastro via API.
- `lib/core/permit_api_service.dart`: perguntas oficiais do MVP, listagem e criação de solicitações via API.
- `lib/features/services/receita_municipal/ui/receita_municipal_services_page.dart`: entrada única do MVP para Alvará de Evento.
- `lib/presentation/pages/user_alvara_dashboard.dart`: lista solicitações reais da API e detalhes por secretaria.
- `lib/features/permit_request/pages/permit_request_page.dart`: tela do fluxo de solicitação.
- `lib/features/permit_request/pages/permit_request_form_builder.dart`: campos por etapa.
- `lib/features/permit_request/controller/permit_request_controller.dart`: estado separado, validação, preview de exigências e submissão via API.

## Riscos técnicos críticos para o MVP

1. Upload de documentos ainda não persiste arquivos.
   O File Picker seleciona arquivos e envia nomes no payload, mas ainda falta upload real com validação de tipo/tamanho e armazenamento.

2. Workflow interno ainda incompleto.
   A API filtra filas por perfil/secretaria, mas ainda faltam ações de aprovar, recusar, solicitar correção, comentar e auditar.

3. Autorização/DAM ainda parcial.
   O sistema registra `DAM pendente na Receita Municipal` ou `isento`. No primeiro momento, o DAM deve ser anexado à solicitação aprovada; a geração automática do DAM fica para integração futura.

4. Observabilidade e auditoria ainda faltam.
   Antes de produção, ações sensíveis devem registrar ator, data/hora, entidade afetada e metadados úteis.

5. Rotas do frontend ainda precisam de guarda central.
   O backend valida JWT/RBAC, mas o app ainda deve centralizar proteção de rota para melhorar UX e reduzir telas indevidas.

6. Configuração de produção precisa ser fechada.
   Definir ambiente de homologação, CORS restrito, HTTPS, secrets, banco real, política de anexos e revisão final de segurança.

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
- `anexado`

## Contratos mínimos de API para o MVP

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/email-verifications`
- `POST /auth/email-verifications/confirm`
- `POST /auth/mfa/generate`
- `POST /auth/mfa/verify`
- `GET /auth/me`
- `GET /permit-types`
- `GET /permit-types/{id}/questions`
- `POST /permit-requests`
- `GET /permit-requests`
- `GET /permit-requests/{id}`
- `POST /permit-requests/{id}/attachments`
- `POST /permit-requests/{id}/dam-attachment`
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
- Quando houver DAM, o documento é anexado à solicitação aprovada antes da autorização final.
