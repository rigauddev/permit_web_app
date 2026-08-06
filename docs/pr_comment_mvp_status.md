# Comentário sugerido para a PR

## Fase atual do MVP

O fluxo principal do cidadão para `Solicitação de Alvará de Evento` está consolidado no app e integrado ao backend:

- Login via API com MFA por e-mail.
- Cadastro PF/PJ com validação prévia de e-mail.
- Usuário admin seedado com permissão total: `admin@prefeitura.local` / senha `123456`.
- Cadastro de usuários internos pela prefeitura via endpoint protegido.
- Operador da Receita seedado para fluxo de DAM: `receita@prefeitura.local` / senha `123456`.
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
- Smoke test backend do DAM:
  - operador da Receita anexa DAM à solicitação: passou;
  - `dam_status` muda para `anexado`: passou;
  - operador de outra secretaria recebe `403`: passou.
- Smoke test backend do fluxo interno:
  - admin cria comentário geral na solicitação: passou;
  - operador aprova exigência da própria secretaria: passou;
  - operador de outra secretaria recebe `403`: passou;
  - solicitação muda para `dam_pendente` após todas as anuências: passou;
  - solicitação muda para `autorizada` após DAM anexado: passou.

## DAM

Neste primeiro momento, o DAM não será gerado automaticamente pelo sistema. O fluxo definido agora é: após aprovação/encaminhamento, o DAM deve ser anexado à solicitação aprovada. A geração automática do DAM fica planejada para uma integração futura.

Já existe endpoint backend para registrar o anexo do DAM por metadados/URL:

- `POST /permit-requests/{request_id}/dam-attachment`
- permitido para `admin` ou usuário interno da `receita_municipal`
- atualiza `dam_status` para `anexado`

## Próximos passos

- Implementar upload binário real de anexos, incluindo UI para anexo específico do DAM.
- Criar telas internas para consumir os endpoints de fila, aprovação, correção e comentários.
- Criar documento final de autorização imprimível/PDF.
- Definir ambiente de homologação e configurações de produção.

## Observação técnica

Durante os testes locais aparece um aviso conhecido de compatibilidade entre `passlib` e `bcrypt` ao ler a versão do pacote, mas os comandos concluíram com sucesso. Recomendo ajustar a versão/pin da dependência antes da homologação.
