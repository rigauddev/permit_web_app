# Arquitetura - DAM, QR Code e Validação de Evento

## Objetivo

Preparar o sistema para o fluxo pós-aprovação do Alvará de Evento:

1. Todas as secretarias responsáveis analisam e aprovam suas etapas.
2. A solicitação fica `aguardando_geracao_dam`, quando não for beneficente.
3. A Secretaria de Desenvolvimento Econômico recebe notificação por e-mail com link para a central filtrada.
4. O DAM é gerado fora do sistema, no primeiro momento, e anexado à solicitação pela Secretaria de Desenvolvimento Econômico.
5. A solicitação fica `aguardando_pagamento_dam` e o cidadão é notificado para pagar e anexar o comprovante.
6. Após o comprovante, a solicitação fica `aguardando_geracao_alvara`.
7. A Secretaria de Desenvolvimento Econômico anexa o alvará final, finaliza a solicitação e o sistema cria a credencial do evento com QR Code.
8. A equipe de plantão pode ler o QR Code e validar a permissão no sistema.

## Status Esperados

Solicitação:

- `enviada`: solicitação registrada.
- `em_analise`: ao menos uma secretaria ainda analisa.
- `pendente_correcao`: existe exigência pendente de documento/correção.
- `indeferida`: alguma secretaria recusou.
- `aguardando_geracao_dam`: todas as anuências foram aprovadas e a SDE deve gerar/anexar o DAM.
- `aguardando_pagamento_dam`: DAM anexado; cidadão deve pagar e anexar o comprovante.
- `aguardando_geracao_alvara`: comprovante do DAM anexado ou evento isento; SDE deve anexar o alvará final.
- `isenta_dam`: evento beneficente com declaração validada.
- `autorizada`: evento liberado, com alvará final anexado e QR Code emitido.
- `cancelada`: solicitação cancelada por usuário autorizado.

DAM:

- `nao_gerado`: ainda não aplicável.
- `pendente_prefeitura`: precisa ser emitido/solicitado na Receita.
- `gerado`: DAM foi anexado ao processo.
- `pago`: comprovante de pagamento foi anexado pelo cidadão.
- `isento`: evento beneficente com declaração aceita.

Credencial do evento:

- `pendente`: autorização ainda não emitida.
- `ativa`: QR Code válido para fiscalização.
- `revogada`: credencial cancelada por decisão administrativa.
- `expirada`: data/hora do evento encerrada.

## Fluxo de DAM

### MVP atual

- O sistema não gera DAM diretamente.
- Após aprovação das secretarias, o status muda para `aguardando_geracao_dam`.
- O sistema notifica a Secretaria de Desenvolvimento Econômico por e-mail com link para `/secretaria-requests?status=aguardando_geracao_dam`.
- A SDE gera o DAM no sistema externo/presencial e anexa o documento no sistema.
- O sistema atualiza `dam_status` para `gerado`, muda a solicitação para `aguardando_pagamento_dam` e notifica o cidadão.
- O cidadão paga o DAM e anexa o comprovante.
- O sistema atualiza `dam_status` para `pago`, muda a solicitação para `aguardando_geracao_alvara` e notifica a SDE com link filtrado para DAM/alvará.
- A SDE anexa o alvará final, finaliza a solicitação como `autorizada` e o sistema emite a credencial/QR Code.

### Futuro

- Integração com sistema da Receita para gerar DAM diretamente.
- Registro do número do DAM, valor, vencimento e status de pagamento.
- Conciliação automática ou manual de pagamento.
- Atualização de `dam_status` para `pago`.

## Credencial e QR Code

Quando a solicitação ficar `autorizada`, o sistema deve criar uma credencial verificável.

Campos sugeridos:

- `id`
- `permit_request_id`
- `codigo_publico`: código curto para consulta manual.
- `token_hash`: hash do token assinado usado no QR Code.
- `status`: `ativa`, `revogada`, `expirada`.
- `valid_from`
- `valid_until`
- `issued_at`
- `issued_by`
- `revoked_at`
- `revoked_by`
- `revocation_reason`

Conteúdo recomendado do QR Code:

```text
https://dominio-da-prefeitura.gov.br/validar-evento/{codigo_publico}?t={token}
```

O QR Code não deve expor dados pessoais diretamente. Ele deve conter apenas um link/token. O backend valida o token e retorna os dados autorizados para fiscalização.

## Tela de Validação

O sistema deve ter uma opção chamada `Validar Credencial de Evento`.

Usuários autorizados:

- `admin`
- `gestor_secretaria`
- `operador_secretaria`
- equipe de plantão/fiscalização, se criada como perfil específico no futuro

Ao ler o QR Code, a tela deve mostrar:

- Status da credencial: válida, revogada, expirada ou inválida.
- Protocolo da solicitação.
- Nome do evento.
- Data e horários.
- Local/endereço.
- Responsável.
- Público estimado.
- Secretarias anuentes.
- Status de cada etapa.
- DAM anexado/pago ou isenção validada.
- Cópia/anexo do DAM, quando houver permissão.
- Observações relevantes para fiscalização.

## Regras de Liberação

O sistema só deve emitir QR Code/credencial quando:

- Todas as exigências aplicáveis estiverem `aprovada`.
- Solicitação não estiver `indeferida`, `cancelada` ou `pendente_correcao`.
- Para evento não beneficente: DAM gerado e comprovante de pagamento anexado no MVP.
- Para evento beneficente: declaração estiver validada e `dam_status = isento`.

## Dependências entre Etapas

Algumas ações só devem ser liberadas depois de outras:

- A SDE só pode anexar o DAM após todas as secretarias aprovarem.
- O cidadão só pode anexar comprovante depois que o DAM estiver anexado.
- Autorização final só pode ser emitida após comprovante do DAM ou isenção validada.
- QR Code só pode ser emitido após autorização final.
- Validação pública/fiscal só deve mostrar evento com credencial ativa.

Regras futuras mais granulares:

- DMTRAN pode depender de croqui/mapa enviado.
- Infraestrutura pode depender de ART, AVCB e laudo de vistoria.
- Vigilância Sanitária pode depender de certificado/documento de alimentação.
- Guarda Civil pode depender de ofício aceito.

## Endpoints Sugeridos

MVP/fase seguinte:

- `POST /permit-requests/{id}/dam-attachment`
- `POST /permit-requests/{id}/dam-payment-proof`
- `POST /permit-requests/{id}/final-permit-attachment`
- `POST /permit-requests/{id}/issue-authorization`
- `GET /permit-requests/{id}/authorization`
- `GET /event-credentials/{codigo_publico}/validate`
- `POST /event-credentials/{id}/revoke`

Futuro com integração DAM:

- `POST /permit-requests/{id}/dam`
- `GET /permit-requests/{id}/dam`
- `PATCH /permit-requests/{id}/dam/payment-status`

## Auditoria Obrigatória

Registrar logs para:

- Anexo do DAM.
- Anexo do comprovante de pagamento do DAM.
- Anexo do alvará final.
- Notificações por e-mail enviadas ou registradas.
- Emissão da autorização.
- Emissão do QR Code.
- Leitura/validação da credencial.
- Revogação de credencial.
- Alteração manual de status de pagamento/isento.

Campos mínimos:

- ator
- perfil
- ação
- entidade
- id da entidade
- data/hora
- IP/user agent quando disponível
- metadados da operação

## Implementado no Backend

- Modelo `EventCredential` vinculado à solicitação.
- Emissão da autorização final por `admin` ou operador/gestor da Secretaria de Desenvolvimento Econômico.
- Geração de `codigo_publico`, token assinado e URL de validação.
- Validação da credencial sem expor dados pessoais no QR Code.
- Revogação administrativa da credencial.
- Retorno dos dados de fiscalização, incluindo status da solicitação, status do DAM, exigências e referência ao anexo do DAM.
- Recuperação da autorização com token válido para renderizar o QR Code depois da emissão.
- Tela Flutter para autorização/QR Code e validação da credencial.
- Geração opcional de PDF imprimível com QR Code para casos em que o documento físico for necessário.
- Validação automática da credencial quando a autorização é aberta no app.
- Logo oficial no cabeçalho da autorização em tela e PDF.
- Template configurável de cabeçalho e rodapé do PDF, editável por gestor/admin.
- Campos de assinatura para responsável do evento e Central de Eventos/Prefeitura.
- Orientação de assinatura: imprimir/assinar/anexar ou baixar o PDF, assinar eletronicamente pelo aplicativo gov.br e anexar o arquivo assinado quando exigido.
- Estados separados para geração do DAM, pagamento do DAM e geração do alvará final.
- Notificação por e-mail via SMTP quando configurado, com fallback registrado nos comentários da solicitação.
- Tela interna com filtro por status para a SDE operar `aguardando_geracao_dam` e `aguardando_geracao_alvara`.
- Tela do cidadão permite anexar comprovante quando a solicitação está `aguardando_pagamento_dam`.

## Próximo Bloco Recomendado

1. Adicionar seed com uma solicitação autorizada para demonstração.
2. Ajustar antecedência mínima para 15 dias úteis no backend e frontend.
3. Criar SLA interno de 2 dias úteis por exigência/secretaria.
4. Testar layout mobile e desktop.
