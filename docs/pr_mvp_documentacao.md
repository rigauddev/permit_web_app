# PR: Documentação e planejamento do MVP de Alvará de Eventos

## Resumo

Esta PR organiza o roadmap e as tarefas executáveis do MVP de solicitação de alvará de eventos.

## Alterações

- Adiciona visão do MVP em `docs/README_MVP_ALVARA.md`.
- Adiciona roadmap de entrega em `docs/roadmap_entrega_mvp.md`.
- Adiciona checklist de execução em `docs/tarefas_execucao_mvp.md`.
- Adiciona descrição sugerida desta PR em `docs/pr_mvp_documentacao.md`.

## Decisões registradas

- O MVP deve focar somente em `Solicitação de Alvará de Evento`.
- A recomendação é manter um único app web/mobile com permissões por perfil.
- A integração automática com DAM fica fora do MVP.
- Nesta fase, o documento final deve indicar DAM pendente na Receita Municipal ou isenção para evento beneficente com declaração.

## Testes

- `flutter analyze`

Resultado atual: o comando executa, mas retorna 33 issues já existentes no projeto, principalmente imports não usados, prints, APIs depreciadas e uso de `BuildContext` após async gap.

## Próximos passos

- Corrigir o estado do formulário de solicitação.
- Implementar perguntas condicionais e exigências por secretaria.
- Substituir mocks por API/persistência.
- Publicar esta branch e abrir PR contra `develop`.
