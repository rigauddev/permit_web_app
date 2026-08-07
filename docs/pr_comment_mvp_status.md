# Comentário sugerido para a PR

## Fase atual do MVP

O fluxo principal do cidadão para `Solicitação de Alvará de Evento` está consolidado no app e integrado ao backend:

- Login via API com MFA por e-mail.
- Cadastro PF/PJ com validação prévia de e-mail.
- Usuário admin seedado com permissão total: `admin@prefeitura.local` / senha `123456`.
- Cadastro de usuários internos pela prefeitura via endpoint protegido.
- Gestor da Secretaria de Desenvolvimento Econômico seedado para fluxo de DAM/alvará: `gestor@prefeitura.local` / senha `123456`.
- Serviço limitado ao MVP de Alvará de Evento, removendo IPTU, notas fiscais e outros alvarás do caminho principal.
- Formulário separado em responsável, documentos, dados do evento, perguntas condicionais e revisão.
- Validação de 15 dias de antecedência, campos obrigatórios e anexos mínimos.
- Geração de protocolo e exigências por secretaria no backend.
- Dashboard lista solicitações reais da API.

## Testes executados

- `flutter analyze`: passou.
- `flutter test`: passou.
- `python3 -m compileall -q permit_system`: passou.
- Smoke test backend com SQLite temporário:
  - login admin + MFA: passou;
  - `/auth/me` admin: passou;
  - listagem de usuários pelo admin: passou;
  - criação de operador interno pelo admin: passou;
  - cadastro PF com validação de e-mail: passou;
  - cadastro PJ com validação de e-mail: passou;
  - operador de Meio Ambiente visualiza apenas solicitação da secretaria: passou;
  - admin visualiza solicitações sem filtro de secretaria: passou.
- Smoke test backend do DAM/alvará:
  - SDE recebe notificação quando todas as exigências são aprovadas: previsto no fluxo.
  - SDE anexa DAM à solicitação em `aguardando_geracao_dam`: implementado.
  - `dam_status` muda para `gerado` e a solicitação fica `aguardando_pagamento_dam`: implementado.
  - cidadão anexa comprovante do DAM e a solicitação fica `aguardando_geracao_alvara`: implementado.
  - SDE anexa alvará final e o sistema emite credencial/QR Code: implementado.
  - operador de outra secretaria recebe `403`: esperado.
- Smoke test backend do fluxo interno:
  - admin cria comentário geral na solicitação: passou;
  - operador aprova exigência da própria secretaria: passou;
  - operador de outra secretaria recebe `403`: passou;
  - solicitação muda para `aguardando_geracao_dam` após todas as anuências: implementado;
  - solicitação só muda para `autorizada` após anexo do alvará final: implementado.
- Smoke test backend da credencial do evento:
  - SDE emite autorização final após comprovante de DAM e alvará anexado: implementado;
  - sistema gera código público e URL de validação: passou;
  - validação da credencial retorna dados do evento, exigências e referência do DAM: passou;
  - revogação da credencial invalida o link: passou.
- Smoke test backend de recuperação da autorização:
  - `GET /permit-requests/{id}/authorization` retorna link com token válido para QR Code: passou;
  - validação pública do link recuperado: passou.
- Frontend:
  - autorização continua como tela principal dentro do app;
  - QR Code é gerado quando o usuário abre a autorização;
  - credencial é validada automaticamente ao abrir a autorização;
  - PDF imprimível pode ser gerado apenas quando necessário;
  - autorização e PDF exibem logo oficial;
  - gestor/admin pode configurar texto de cabeçalho e rodapé do PDF;
  - PDF inclui campos de assinatura;
  - usuário pode escolher imprimir/assinar/anexar ou gerar PDF para assinar eletronicamente pelo aplicativo gov.br e anexar o arquivo assinado quando exigido.
- Smoke test backend do template de PDF:
  - leitura/criação do template padrão: passou;
  - atualização do cabeçalho/rodapé por gestor: passou.

## DAM

Neste primeiro momento, o DAM não será gerado automaticamente pelo sistema. O fluxo definido agora é: após todas as anuências, a Secretaria de Desenvolvimento Econômico gera o DAM fora do sistema e anexa o documento. O cidadão paga e anexa o comprovante. Depois a SDE anexa o alvará final e finaliza a solicitação. A geração automática do DAM fica planejada para uma integração futura.

Já existe endpoint backend para registrar o anexo do DAM por metadados/URL:

- `POST /permit-requests/{request_id}/dam-attachment`
- permitido para `admin` ou usuário interno da `desenvolvimento_economico`
- atualiza `dam_status` para `gerado`
- muda a solicitação para `aguardando_pagamento_dam`

Também foram adicionados:

- `POST /permit-requests/{request_id}/dam-payment-proof`
- `POST /permit-requests/{request_id}/final-permit-attachment`
- notificação por e-mail via SMTP quando configurado, com fallback registrado no histórico da solicitação.

## Credencial / QR Code

O backend já emite a credencial verificável do evento autorizado:

- `POST /permit-requests/{request_id}/issue-authorization`
- `GET /permit-requests/{request_id}/authorization`
- `GET /event-credentials/{codigo_publico}/validate?t={token}`
- `POST /event-credentials/{credential_id}/revoke`

Nesta etapa foi entregue o link/token seguro para validação, a recuperação da autorização com token válido, a tela Flutter de autorização, a tela de validação da credencial com QR Code visual e a geração opcional de PDF imprimível. A operação principal permanece dentro do app.

## Próximos passos

- Implementar upload binário real de anexos, incluindo UI para anexo específico do DAM.
- Criar telas internas para consumir os endpoints de fila, aprovação, correção e comentários.
- Ajustar regra de antecedência para 15 dias úteis no backend e frontend.
- Criar SLA interno de 2 dias úteis por secretaria.
- Testar layout mobile e desktop.
- Definir ambiente de homologação e configurações de produção.

## Observação técnica

Durante os testes locais aparece um aviso conhecido de compatibilidade entre `passlib` e `bcrypt` ao ler a versão do pacote, mas os comandos concluíram com sucesso. Recomendo ajustar a versão/pin da dependência antes da homologação.
