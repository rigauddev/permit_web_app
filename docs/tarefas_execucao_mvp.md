# Tarefas de Execução - MVP Alvará de Eventos

## Marco 1 - Preparação e escopo

- [x] Criar roadmap do MVP.
- [x] Criar lista de tarefas executáveis.
- [x] Registrar decisão de manter um único app com perfis.
- [ ] Configurar branch remota para PR.
- [ ] Definir ambiente de homologação.

## Marco 2 - Fluxo do cidadão

- [ ] Limitar tela de serviços ao MVP de `Solicitação de Alvará de Evento`.
- [ ] Criar cadastro PF/PJ.
- [ ] Corrigir estado do formulário para separar dados do responsável, evento, respostas e anexos.
- [ ] Validar antecedência mínima de 15 dias.
- [ ] Validar campos obrigatórios do evento: nome, data, local, público esperado, início e término.
- [ ] Validar anexos obrigatórios: RG/CPF, comprovante de residência e alvará do local.
- [ ] Criar tela de revisão antes do envio.
- [ ] Gerar protocolo após envio.

## Marco 3 - Perguntas condicionais

- [ ] Perguntar se o evento terá som.
- [ ] Perguntar se terá palco.
- [ ] Perguntar se terá gerador.
- [ ] Perguntar se terá trio elétrico.
- [ ] Perguntar se usará ou bloqueará vias.
- [ ] Perguntar se terá alimentação.
- [ ] Perguntar se precisará da Guarda Civil Municipal.
- [ ] Perguntar se exigirá brigadista.
- [ ] Perguntar se é evento beneficente.
- [ ] Exibir exigências geradas antes do envio.

## Marco 4 - Regras por secretaria

- [ ] Som -> Meio Ambiente.
- [ ] Palco/gerador -> Infraestrutura.
- [ ] Trio elétrico -> DMTRAN.
- [ ] Bloqueio/uso de via -> DMTRAN.
- [ ] Alimentação -> Vigilância Sanitária.
- [ ] Guarda Civil -> Guarda Civil Municipal.
- [ ] Beneficente -> declaração e isenção de DAM.

## Marco 5 - Fluxo interno

- [ ] Criar fila por secretaria.
- [ ] Garantir que operador veja apenas demandas da sua secretaria.
- [ ] Criar ações: aprovar, recusar, solicitar correção e comentar.
- [ ] Criar status por secretaria.
- [ ] Atualizar status geral a partir das anuências.
- [ ] Criar visão de gestor/admin para todas as secretarias.

## Marco 6 - Backend e persistência

- [ ] Implementar API mínima.
- [ ] Criar autenticação no backend.
- [ ] Remover usuários mockados do caminho de produção.
- [ ] Criar modelos de usuários, secretarias, solicitações, exigências, anexos e comentários.
- [ ] Criar upload com validação de tipo/tamanho.
- [ ] Criar logs de auditoria.
- [ ] Criar camada de API no Flutter.
- [ ] Substituir mocks por chamadas HTTP.

## Marco 7 - Documento final e DAM

- [ ] Criar documento de autorização em HTML/PDF imprimível.
- [ ] Incluir protocolo, responsável, evento, data, local, secretarias anuentes e observações.
- [ ] Quando não beneficente, marcar `DAM pendente na Receita Municipal`.
- [ ] Quando beneficente, exigir declaração e marcar `Isento de DAM`.

## Marco 8 - Testes

- [ ] Rodar `flutter analyze` e corrigir issues bloqueantes.
- [ ] Testar cadastro PF.
- [ ] Testar cadastro PJ.
- [ ] Testar login.
- [ ] Testar solicitação completa.
- [ ] Testar evento com som.
- [ ] Testar evento com palco/gerador.
- [ ] Testar evento com trio elétrico.
- [ ] Testar evento com bloqueio de via.
- [ ] Testar evento com alimentação.
- [ ] Testar evento beneficente.
- [ ] Testar operador de secretaria.
- [ ] Testar aprovação, recusa e pedido de correção.
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
