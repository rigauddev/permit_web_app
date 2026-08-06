# Tarefas de Execução - MVP Alvará de Eventos

## Marco 1 - Preparação e escopo

- [x] Criar roadmap do MVP.
- [x] Criar lista de tarefas executáveis.
- [x] Registrar decisão de manter um único app com perfis.
- [x] Configurar branch remota para PR.
- [ ] Definir ambiente de homologação.

## Marco 2 - Fluxo do cidadão

- [x] Limitar tela de serviços ao MVP de `Solicitação de Alvará de Evento`.
- [x] Criar cadastro PF/PJ com validação de e-mail antes do formulário.
- [x] Corrigir estado do formulário para separar dados do responsável, evento, respostas e anexos.
- [x] Validar antecedência mínima de 15 dias.
- [x] Validar campos obrigatórios do evento: nome, data, local, público esperado, início e término.
- [x] Validar anexos obrigatórios: RG/CPF, comprovante de residência e alvará do local.
- [x] Criar tela de revisão antes do envio.
- [x] Gerar protocolo após envio.

## Marco 3 - Perguntas condicionais

- [x] Perguntar se o evento terá som.
- [x] Perguntar se o evento será em local fixo sem alvará de funcionamento.
- [x] Perguntar se exigirá AVCB.
- [x] Perguntar se terá palco.
- [x] Perguntar se terá gerador.
- [x] Perguntar se exigirá planta baixa.
- [x] Perguntar se terá trio elétrico.
- [x] Perguntar se usará ou bloqueará vias.
- [x] Perguntar se terá alimentação.
- [x] Perguntar se precisará de ambulância no local.
- [x] Perguntar se precisará da Guarda Civil Municipal.
- [x] Perguntar se exigirá brigadista.
- [x] Perguntar se é evento beneficente.
- [x] Exibir exigências geradas antes do envio.

## Marco 4 - Regras por secretaria

- [x] Som -> Meio Ambiente.
- [x] Local fixo sem alvará -> Desenvolvimento Econômico.
- [x] AVCB -> Infraestrutura.
- [x] Palco/gerador -> Infraestrutura, vistoria e ART.
- [x] Planta baixa -> Infraestrutura.
- [x] Trio elétrico -> DMTRAN.
- [x] Bloqueio/uso de via -> DMTRAN e croqui/mapa do circuito.
- [x] Alimentação -> Vigilância Sanitária.
- [x] Ambulância -> Secretaria de Saúde.
- [x] Guarda Civil -> Guarda Civil Municipal.
- [x] Beneficente -> declaração e isenção de DAM.

## Marco 5 - Fluxo interno

- [x] Criar fila por secretaria.
- [x] Garantir que operador veja apenas demandas da sua secretaria.
- [x] Criar ações: aprovar, recusar, solicitar correção e comentar.
- [x] Criar status por secretaria.
- [x] Atualizar status geral a partir das anuências.
- [ ] Criar visão de gestor/admin para todas as secretarias.

## Marco 6 - Backend e persistência

- [x] Implementar API mínima de login, usuário atual e solicitações.
- [x] Criar autenticação no backend.
- [x] Remover usuários mockados do caminho de produção.
- [x] Criar modelos de usuários, secretarias, solicitações, exigências e anexos.
- [x] Criar modelo de comentários.
- [ ] Criar upload com validação de tipo/tamanho.
- [ ] Criar logs de auditoria.
- [x] Criar camada inicial de API de autenticação no Flutter.
- [x] Substituir mock de login por chamadas HTTP com MFA.
- [x] Identificar tipo de usuário pelo `role` retornado no login/JWT.
- [x] Exibir escolha de acesso Cidadão ou Prefeitura antes do login.
- [x] Substituir mocks de solicitações por chamadas HTTP.
- [x] Criar seeds de usuários, secretarias e solicitação de exemplo.

## Marco 7 - Documento final e DAM

- [ ] Criar documento de autorização em HTML/PDF imprimível.
- [ ] Incluir protocolo, responsável, evento, data, local, secretarias anuentes e observações.
- [ ] Quando não beneficente, marcar `DAM pendente na Receita Municipal`.
- [x] Permitir anexar o DAM à solicitação aprovada.
- [ ] Quando beneficente, exigir declaração e marcar `Isento de DAM`.

## Marco 8 - Testes

- [x] Rodar `flutter analyze` e corrigir issues bloqueantes.
- [x] Testar cadastro PF.
- [x] Testar cadastro PJ.
- [x] Testar login.
- [x] Testar login backend com MFA por e-mail em ambiente local.
- [x] Testar solicitação completa.
- [x] Testar evento com som.
- [x] Testar evento com palco/gerador.
- [ ] Testar evento com trio elétrico.
- [x] Testar evento com bloqueio de via.
- [x] Testar evento com alimentação.
- [ ] Testar evento beneficente.
- [x] Testar operador de secretaria.
- [x] Testar aprovação, recusa e pedido de correção.
- [ ] Testar geração do documento final.
- [ ] Testar layout mobile e desktop.

## Prioridade de implementação

1. Corrigir estado do formulário.
2. Fechar perguntas e regras de exigência.
3. Esconder serviços fora do MVP.
4. Criar revisão/envio/protocolo.
5. Implementar persistência/API mínima.
6. Implementar fila interna por secretaria.
7. Criar documento final.
8. Fazer limpeza de segurança e QA.
