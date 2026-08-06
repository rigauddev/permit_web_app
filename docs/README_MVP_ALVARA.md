# MVP - Alvará de Eventos

Esta pasta reúne o planejamento executável do MVP de solicitação de alvará/licença para eventos municipais.

## Documentos

- [Roadmap de entrega](./roadmap_entrega_mvp.md)
- [Tarefas de execução](./tarefas_execucao_mvp.md)
- [Regras da Central de Eventos](./regras_central_eventos_ata.md)
- [Descrição sugerida da PR](./pr_mvp_documentacao.md)

## Estrutura do projeto

O repositório do app agora concentra frontend e backend:

- `lib/`: frontend Flutter web/mobile.
- `permit_system/`: backend FastAPI.
- `docs/`: documentação e planejamento do MVP.

O backend foi movido para dentro do app sem incluir `.env`, `.venv`, caches ou arquivos locais.

## Escopo da primeira entrega

O primeiro serviço em produção será a solicitação de alvará de festa/evento. O usuário externo se cadastra como pessoa física ou jurídica, informa dados do responsável e do evento, anexa documentos obrigatórios e responde perguntas condicionais. A partir das respostas, o sistema cria pendências por secretaria/órgão responsável.

Nesta fase, o sistema ainda não integra com o gerador de DAM. O documento final deve indicar `DAM pendente na Receita Municipal` ou `Isento de DAM` para evento beneficente com declaração.

## Decisão de produto

Para a entrega de sexta-feira, 07/08/2026, a recomendação é manter um único app web/mobile com perfis e permissões:

- cidadão.
- operador de secretaria.
- gestor de secretaria.
- admin.

Separar app do cidadão e app interno deve ficar para uma fase posterior.
