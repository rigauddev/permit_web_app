# Fluxo de ensino do sistema

Objetivo: treinar cidadão, operador, gestor e admin em blocos curtos, com demonstrações práticas.

## 1. Acesso e perfis

Público: todos.

Conteúdo:

- Diferença entre Portal do Cidadão e Portal do Servidor.
- Cidadão entra com CPF/CNPJ e senha.
- Usuário interno entra com e-mail institucional e senha.
- MFA por e-mail fica opcional.
- Recarregar a página mantém a sessão enquanto ela estiver válida.

Resultado esperado: usuário entende por onde entrar e qual credencial usar.

## 2. Cadastro do cidadão

Público: cidadão e atendimento assistido.

Conteúdo:

- Escolher PF ou PJ.
- Informar CPF/CNPJ válido.
- E-mail é opcional para cidadão.
- Tirar foto ou anexar foto existente.
- Anexar comprovante de residência em nome do usuário, pai ou mãe.
- Informar que somente contas de água ou luz serão consideradas para comprovação inicial.
- Aceitar termo de responsabilidade.

Resultado esperado: cidadão cadastrado e apto a solicitar alvará.

## 3. Solicitação de alvará de evento

Público: cidadão.

Conteúdo:

- Entrar na área de serviços.
- Selecionar Alvará de Evento.
- Escolher tipo de evento.
- Conferir descrição, exemplos e documentos exigidos.
- Iniciar nova solicitação.
- Preencher dados do responsável e do evento.
- Escolher público estimado e observar prazo mínimo em dias úteis.
- Preencher perguntas condicionais.
- Usar pergunta de rota do evento quando houver bloqueio/desvio de via.
- Anexar documentos.
- Revisar e enviar.

Resultado esperado: solicitação criada com protocolo.

## 4. Acompanhamento pelo cidadão

Público: cidadão.

Conteúdo:

- Acessar Minhas solicitações.
- Ver status geral.
- Abrir detalhes.
- Responder correções solicitadas.
- Anexar documentos corrigidos.
- Acompanhar DAM, alvará final e QR Code quando disponíveis.

Resultado esperado: cidadão sabe acompanhar e responder exigências.

## 5. Atendimento interno por secretaria

Público: operador e gestor.

Conteúdo:

- Acessar Central de Solicitações.
- Filtrar por status/protocolo quando necessário.
- Abrir detalhes da solicitação.
- Ver respostas do cidadão, textos preenchidos e anexos.
- Avaliar exigências da própria secretaria.
- Aprovar, recusar ou solicitar correção.
- Registrar comentários claros.

Resultado esperado: secretaria consegue analisar a demanda sem pedir dados fora do sistema.

## 6. Vistorias

Público: operador e gestor.

Conteúdo:

- Acessar Vistorias.
- Ver vistorias do dia, futuras e realizadas.
- Agendar data e horário.
- Confirmar vistoria para notificar cidadão.
- Reagendar quando necessário.
- Realizar vistoria apenas após confirmação.
- Preencher checklist.
- Anexar fotos quando obrigatório.
- Finalizar com aprovação ou correção.

Resultado esperado: fluxo de vistoria rastreável e comunicado ao cidadão.

## 7. Gestão de serviços

Público: gestor e admin.

Conteúdo:

- Criar e editar perguntas.
- Definir secretaria responsável.
- Definir prazo interno em dias úteis.
- Selecionar campos de resposta.
- Usar `Rota do Evento` para perguntas que precisam capturar percurso.
- Vincular pergunta a categorias de evento.
- Configurar faixas de público e prazo mínimo.
- Criar e editar categorias de evento com descrição e exemplos.

Resultado esperado: gestores ajustam o formulário sem alteração de código.

## 8. Relatórios

Público: secretaria, gestor e admin.

Conteúdo:

- Filtrar por período.
- Filtrar por ano.
- Filtrar por tipo de evento.
- Ver área/secretaria com mais eventos.
- Ver tipo de evento mais frequente.
- Ver mês mais frequente.
- Ver bairro com mais eventos.
- Ver tipos de eventos concentrados no bairro.
- Consultar lista de eventos do recorte.

Resultado esperado: equipe usa dados para planejamento operacional.

## 9. Publicação e suporte

Público: equipe técnica.

Conteúdo:

- Branches de trabalho, release e main.
- Rodar validações antes de merge.
- Subir Docker Compose.
- Verificar saúde de web, API e banco.
- Monitorar logs.
- Fazer backup do banco antes de atualizações.

Resultado esperado: MVP publicado com rotina mínima de manutenção.
