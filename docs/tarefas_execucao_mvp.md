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
- [ ] Ajustar validação de antecedência mínima para 15 dias úteis.
- [x] Validar campos obrigatórios do evento: nome, data, local, público esperado, início e término.
- [x] Validar anexos obrigatórios: RG/CPF, comprovante de residência e alvará do local.
- [x] Criar tela de revisão antes do envio.
- [x] Gerar protocolo após envio.
- [ ] Exibir que a Secretaria de Desenvolvimento Econômico coordena a Central de Eventos.
- [x] Corrigir seleção de respostas para não carregar resposta da pergunta anterior no wizard.
- [x] Corrigir menu do cidadão para ocultar áreas internas de gestão, secretaria e configurações.
- [x] Criar página inicial do cidadão com carrossel de informações da prefeitura/secretarias.
- [x] Centralizar formulários de solicitação em largura adequada para desktop.

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
- [x] Criar visão de gestor/admin para gestão interna com escopo por secretaria.
- [x] Criar dashboard inicial para usuários internos com serviços pertinentes ao perfil/secretaria.
- [ ] Criar prazo interno de 2 dias úteis por exigência/secretaria.
- [ ] Exibir alertas de análise próxima do vencimento.
- [ ] Garantir que Receita/Fazenda só anexe DAM após todas as anuências aplicáveis.

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
- [x] Exibir código MFA de teste em desenvolvimento e registrar no console para validação manual.
- [x] Bloquear reenvio de MFA por 60 segundos com contador regressivo.
- [x] Substituir mocks de solicitações por chamadas HTTP.
- [x] Criar seeds de usuários, secretarias e solicitação de exemplo.
- [x] Substituir lista mockada de usuários por endpoint real com secretaria e perfil.
- [x] Restringir gestor a usuários da própria secretaria e impedir criação de admin por gestor.
- [x] Criar gestão de conteúdo da página inicial com até 5 cards ativos por prefeitura/secretaria.
- [x] Persistir cards de carrossel com título, texto, imagem e ordem de exibição.

## Marco 7 - Documento final e DAM

- [x] Criar documento de autorização em PDF imprimível como opção.
- [x] Incluir protocolo, responsável, evento, data, local, secretarias anuentes e observações.
- [x] Incluir logo oficial na autorização em tela e no PDF.
- [x] Criar template configurável de cabeçalho e rodapé do PDF.
- [x] Permitir que gestor/admin atualize textos do template do PDF.
- [x] Incluir campos de assinatura no rodapé da autorização/PDF.
- [x] Orientar assinatura impressa ou assinatura eletrônica pelo aplicativo gov.br quando exigida.
- [ ] Quando não beneficente, marcar `DAM pendente na Receita Municipal`.
- [x] Permitir anexar o DAM à solicitação aprovada.
- [ ] Quando beneficente, exigir declaração validada e marcar `Isento de DAM`.
- [x] Emitir autorização final após DAM anexado ou isenção validada.
- [x] Gerar credencial/link de validação do evento autorizado no backend.
- [x] Gerar QR Code visual para impressão/exibição.
- [x] Criar tela de validação de credencial do evento.
- [x] Validar automaticamente a credencial quando a autorização é aberta no app.
- [x] Exibir referência do DAM armazenado na validação quando autorizado.
- [x] Exibir autorização final em nome do responsável pelo evento.

## Marco 8 - Vistoria e análise técnica

- [ ] Criar fluxo de vistoria quando exigência depender de inspeção técnica.
- [ ] Permitir anexar imagens da vistoria.
- [ ] Criar formulário de laudo técnico.
- [ ] Vincular laudo à exigência da secretaria responsável.
- [ ] Bloquear aprovação final da exigência enquanto laudo obrigatório estiver pendente.
- [ ] Registrar ART, AVCB, planta baixa, croqui/mapa e certificado sanitário como anexos específicos.

## Marco 9 - Pós-MVP / Integrações

- [ ] Integrar geração automática de DAM com sistema da Receita.
- [ ] Integrar assinatura eletrônica quando exigida.
- [ ] Enviar e-mail para secretarias responsáveis com cópia/resumo da solicitação e link de acesso.
- [ ] Enviar notificações push para pendências, correções e autorizações.

## Marco 10 - Testes

- [x] Rodar `flutter analyze` e corrigir issues bloqueantes.
- [x] Testar cadastro PF.
- [x] Testar cadastro PJ.
- [x] Testar login.
- [x] Testar login backend com MFA por e-mail em ambiente local.
- [x] Testar contador/reenvio de MFA em desenvolvimento.
- [x] Testar solicitação completa.
- [x] Testar evento com som.
- [x] Testar evento com palco/gerador.
- [ ] Testar evento com trio elétrico.
- [x] Testar evento com bloqueio de via.
- [x] Testar evento com alimentação.
- [ ] Testar evento beneficente.
- [x] Testar operador de secretaria.
- [x] Testar listagem de usuários: admin vê todos e gestor vê apenas sua secretaria.
- [ ] Testar gestão de conteúdo por admin e gestor de secretaria.
- [ ] Testar home do cidadão com carrossel em mobile e desktop.
- [x] Testar aprovação, recusa e pedido de correção.
- [ ] Testar regra de 15 dias úteis.
- [ ] Testar prazo interno de 2 dias úteis por secretaria.
- [x] Testar geração do documento final.
- [x] Testar QR Code visual e tela de validação.
- [ ] Testar layout mobile e desktop.

## Prioridade de implementação

1. Corrigir estado do formulário.
2. Fechar perguntas e regras de exigência.
3. Esconder serviços fora do MVP.
4. Criar revisão/envio/protocolo.
5. Implementar persistência/API mínima.
6. Implementar fila interna por secretaria.
7. Ajustar 15 dias úteis e SLA interno de 2 dias úteis.
8. Criar visão gestor/admin para todas as secretarias.
9. Testar layout mobile e desktop.
10. Fazer limpeza de segurança e QA.
