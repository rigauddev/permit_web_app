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
- [x] Exibir termo de responsabilidade e veracidade das informações antes do envio.
- [x] Exigir aceite do termo de responsabilidade no frontend e backend.
- [x] Exigir leitura do termo até o final antes de liberar aceitar ou recusar.
- [x] Exigir aceite do termo de responsabilidade também no auto cadastro do cidadão.
- [x] Gerar protocolo após envio.
- [ ] Exibir que a Secretaria de Desenvolvimento Econômico coordena a Central de Eventos.
- [x] Corrigir seleção de respostas para não carregar resposta da pergunta anterior no wizard.
- [x] Corrigir menu do cidadão para ocultar áreas internas de gestão, secretaria e configurações.
- [x] Criar página inicial do cidadão com carrossel de informações da prefeitura/secretarias.
- [x] Centralizar formulários de solicitação em largura adequada para desktop.
- [x] Criar menu lateral recolhível, com modo apenas ícones e item ativo destacado.
- [x] Manter menu fixo como parte do layout em páginas autenticadas, inclusive recolhido em telas menores.
- [x] Ocultar botão de menu da app bar superior em mobile e manter acesso pelo menu inferior.
- [x] Mover acesso ao perfil para o avatar/botão do menu e remover atalho do appbar superior.
- [x] Incluir botão de voltar nas subpáginas principais.
- [x] Criar página `Minhas solicitações` separada por tipo de serviço.
- [x] Ajustar `Minhas solicitações` para mobile com cards responsivos e tela de detalhes.
- [x] Exibir ações da solicitação conforme status na tela de detalhes do cidadão.
- [x] Fixar dados do responsável pelo evento a partir da conta logada.
- [x] Buscar dados completos do cidadão sob demanda ao iniciar nova solicitação.
- [x] Organizar catálogo de serviços por categoria Prefeitura/Secretarias, mantendo apenas Alvará de Evento ativo no MVP.
- [x] Permitir marcar serviços como favoritos e exibir lista de favoritos no mobile.

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
- [x] Exibir descrição/orientação de preenchimento definida pelo gestor em cada pergunta.
- [x] Mostrar no resumo da solicitação perguntas respondidas com arquivo pendente de envio.

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
- [x] Garantir que gestor veja solicitações vinculadas à própria secretaria.
- [x] Criar ações: aprovar, recusar, solicitar correção e comentar.
- [x] Criar status por secretaria.
- [x] Atualizar status geral a partir das anuências.
- [x] Criar visão de gestor/admin para gestão interna com escopo por secretaria.
- [x] Criar dashboard inicial para usuários internos com serviços pertinentes ao perfil/secretaria.
- [x] Criar central interna de solicitações por tipo de serviço e secretaria responsável.
- [x] Tornar as exigências da solicitação interativas para admin, gestor e operador autorizados.
- [x] Bloquear rotas internas no frontend quando o perfil logado não possuir permissão.
- [x] Reorganizar menu lateral por Atendimento e Configuração, reduzindo itens duplicados.
- [x] Mover criação de perguntas para a área de Gestão de Serviços no menu.
- [x] Reorganizar menu por contexto: Serviços do cidadão, Atendimento interno, Gestão de Serviços e Gestão do Sistema.
- [x] Ajustar cards da home interna para refletir Gestão de Serviços, Gestão do Sistema e Permissões.
- [ ] Criar prazo interno de 2 dias úteis por exigência/secretaria.
- [ ] Exibir alertas de análise próxima do vencimento.
- [x] Garantir que a Secretaria de Desenvolvimento Econômico só anexe DAM após todas as anuências aplicáveis.

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
- [x] Validar tipo de acesso escolhido já na etapa e-mail/senha, antes do MFA.
- [x] Padronizar falhas de autenticação como `Credenciais inválidas`.
- [x] Limpar campos de login/senha/MFA ao trocar o tipo de acesso.
- [x] Deslogar automaticamente o usuário quando a sessão/token expirar.
- [x] Restaurar sessão salva ao recarregar o app e evitar loop de login.
- [x] Emitir sessão web com validade de 2 horas e sessão app com validade de 2 dias.
- [x] Manter resposta de MFA com dados mínimos e carregar perfil completo via `/auth/me` quando necessário.
- [x] Exibir código MFA de teste em desenvolvimento e registrar no console para validação manual.
- [x] Bloquear reenvio de MFA por 60 segundos com contador regressivo.
- [x] Substituir mocks de solicitações por chamadas HTTP.
- [x] Criar seeds de usuários, secretarias e solicitação de exemplo.
- [x] Criar seed com gestor e operador para cada secretaria.
- [x] Criar seed com reset do banco e cenários de teste do fluxo de alvará.
- [x] Criar numeração de protocolo por serviço no formato `AL-EV0001`.
- [x] Substituir lista mockada de usuários por endpoint real com secretaria e perfil.
- [x] Restringir gestor a usuários da própria secretaria e impedir criação de admin por gestor.
- [x] Criar gestão de secretarias com e-mail, logo e textos de cabeçalho/rodapé.
- [x] Permitir excluir/inativar secretaria pela gestão do admin.
- [x] Preparar pasta `docs/imagens/logo` para logos de secretarias usadas em templates.
- [x] Criar gestão de conteúdo da página inicial com até 5 cards ativos por prefeitura/secretaria.
- [x] Persistir cards de carrossel com título, texto, imagem e ordem de exibição.
- [x] Criar seed de permissões por categoria e vínculo inicial por perfil de usuário.
- [x] Criar tela de gestão de perfis/permissões para admin.
- [ ] Migrar guards do frontend/backend para validação granular por permissão além do perfil base.

## Marco 7 - Documento final e DAM

- [x] Criar documento de autorização em PDF imprimível como opção.
- [x] Incluir protocolo, responsável, evento, data, local, secretarias anuentes e observações.
- [x] Incluir logo oficial na autorização em tela e no PDF.
- [x] Criar template configurável de cabeçalho e rodapé do PDF.
- [x] Permitir que gestor/admin atualize textos do template do PDF.
- [x] Incluir campos de assinatura no rodapé da autorização/PDF.
- [x] Orientar assinatura impressa ou assinatura eletrônica pelo aplicativo gov.br quando exigida.
- [x] Quando não beneficente, marcar `Aguardando geração do DAM` após todas as anuências.
- [x] Permitir anexar o DAM à solicitação aprovada.
- [x] Notificar a Secretaria de Desenvolvimento Econômico quando a solicitação estiver pronta para geração do DAM.
- [x] Após anexo do DAM, marcar `Aguardando pagamento do DAM` e notificar o cidadão.
- [x] Permitir que o cidadão anexe o comprovante de pagamento do DAM.
- [x] Após comprovante, marcar `Aguardando geração do alvará` e notificar a Secretaria de Desenvolvimento Econômico.
- [x] Permitir que a Secretaria de Desenvolvimento Econômico anexe o alvará final.
- [x] Exigir que o alvará final anexado pela SDE seja PDF e fique disponível ao cidadão.
- [x] Permitir anexar o alvará final em PDF após pagamento do DAM, deixando o arquivo disponível para visualizar/baixar/imprimir.
- [x] Transformar anexos de DAM e comprovante em ação de upload/seleção de arquivo.
- [ ] Quando beneficente, exigir declaração validada e marcar `Isento de DAM`.
- [x] Emitir autorização final após alvará anexado ou isenção validada.
- [x] Gerar credencial/link de validação do evento autorizado no backend.
- [x] Gerar QR Code visual para impressão/exibição.
- [x] Criar tela de validação de credencial do evento.
- [x] Validar automaticamente a credencial quando a autorização é aberta no app.
- [x] Marcar credencial/evento como verificado após leitura válida do QR Code.
- [x] Exibir flag de evento verificado nos cards de solicitação do cidadão.
- [x] Exibir referência do DAM armazenado na validação quando autorizado.
- [x] Exibir autorização final em nome do responsável pelo evento.
- [x] Atualizar template padrão do documento para `Alvará de Autorização de Evento`.

## Marco 8 - Vistoria e análise técnica

- [x] Criar visão inicial de vistorias e pendências por secretaria.
- [x] Separar exigências técnicas em realizadas, do dia e futuras.
- [x] Exibir calendário mensal com marcação de dias com vistoria/exigência técnica.
- [x] Reduzir calendário para mês atual e abrir lista de vistorias ao clicar em data marcada.
- [x] Exibir detalhes da solicitação ao clicar em uma vistoria.
- [x] Criar fluxo de vistoria quando exigência depender de inspeção técnica.
- [x] Permitir anexar imagens da vistoria.
- [x] Criar formulário/checklist técnico de vistoria.
- [x] Vincular resultado/checklist à exigência da secretaria responsável.
- [x] Bloquear aprovação da vistoria quando checklist obrigatório estiver incompleto.
- [ ] Registrar ART, AVCB, planta baixa, croqui/mapa e certificado sanitário como anexos específicos.

## Marco 9 - Pós-MVP / Integrações

- [ ] Integrar geração automática de DAM com sistema da Receita.
- [ ] V2: integrar verificação automática de pagamento do DAM com o sistema da Receita.
- [ ] Integrar assinatura eletrônica quando exigida.
- [x] Enviar e-mail para a Secretaria de Desenvolvimento Econômico nas etapas de geração do DAM e geração do alvará, com link filtrado da central.
- [x] Preparar SMTP/Gmail para testes de envio de e-mail.
- [x] Criar template HTML de MFA com cabeçalho da prefeitura e logo/texto da secretaria quando aplicável.
- [x] Permitir modelo de documento por pergunta, com botão de baixar, assinatura impressa/gov.br e anexo obrigatório.
- [x] Permitir selecionar/referenciar arquivo-modelo na criação da pergunta.
- [x] Destacar upload de modelo na criação da pergunta e recarregar lista a partir do banco após salvar.
- [x] Atualizar seed de bloqueio de via com modelo em `docs/arquivos` para download no teste.
- [x] Limpar formulário após cadastrar ou atualizar pergunta.
- [x] Permitir configurar na pergunta se ela exige vistoria e quais itens compõem o checklist.
- [ ] Enviar e-mail para todas as secretarias responsáveis com cópia/resumo da solicitação e link de acesso.
- [ ] Configurar provedor SMTP de produção e validar entregabilidade.
- [ ] Evoluir Gmail para OAuth/Gmail API ou SMTP relay Workspace em homologação/produção.
- [ ] Enviar notificações push para pendências, correções e autorizações.

## Marco 10 - Testes

- [x] Rodar `flutter analyze` e corrigir issues bloqueantes.
- [x] Testar cadastro PF.
- [x] Testar cadastro PJ.
- [x] Testar login.
- [x] Testar login backend com MFA por e-mail em ambiente local.
- [x] Testar seed resetado com cenários `AL-EV0001` a `AL-EV0006`.
- [x] Testar geração do próximo protocolo `AL-EV0007`.
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
- [x] Testar validação de acesso cidadão/prefeitura antes do MFA.
- [ ] Testar gestão de conteúdo por admin e gestor de secretaria.
- [ ] Testar home do cidadão com carrossel em mobile e desktop.
- [ ] Testar menu recolhível e destaque de rota ativa em mobile e desktop.
- [ ] Testar bloqueio de rotas por perfil digitando URLs internas como cidadão.
- [ ] Testar acompanhamento de solicitações do cidadão separado por tipo.
- [ ] Testar catálogo de serviços por categoria Prefeitura/Secretarias.
- [x] Testar aprovação, recusa e pedido de correção.
- [ ] Testar central interna de solicitações por secretaria em mobile e desktop.
- [ ] Testar visão de vistorias e calendário em mobile e desktop.
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
