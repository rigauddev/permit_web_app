# Roadmap de Entrega - MVP Alvará de Eventos

Considerando a data atual de quinta-feira, 06/08/2026, a meta realista é fechar um MVP demonstrável e homologável até sexta-feira, 07/08/2026, com estabilização até segunda-feira, 10/08/2026.

Antes de executar novas tarefas, consulte `docs/prompts_master.md` e `docs/regras_central_eventos_ata.md`.

## Diretrizes da Central de Eventos

- A Secretaria de Desenvolvimento Econômico centraliza a solicitação e coordena as demais análises.
- A solicitação deve ser aberta com 15 dias úteis de antecedência.
- Cada secretaria/órgão deve analisar sua demanda em até 2 dias úteis.
- A Receita/Fazenda só atua no DAM após documentação e anuências completas.
- O cidadão deve acompanhar tudo em um único sistema.

## Quarta-feira, 05/08/2026

Objetivo: travar escopo e remover riscos óbvios.

- Consolidar documentação de produto, técnica e execução.
- Definir modelo de dados do MVP.
- Corrigir estado do formulário para separar responsável, evento, respostas e anexos.
- Trocar perguntas mockadas por lista completa do fluxo de evento.
- Esconder serviços fora do MVP ou marcá-los como indisponíveis.
- Definir navegação web/mobile do fluxo principal.

## Quinta-feira, 06/08/2026

Objetivo: fazer o fluxo funcionar de ponta a ponta.

- Cadastro PF/PJ com validação de e-mail.
- Backend FastAPI com login, MFA, usuário atual e solicitações.
- Criação de solicitação com protocolo.
- Geração de pendências por secretaria a partir das respostas.
- Fila interna por secretaria.
- Aprovação, recusa, pedido de correção e comentários.
- DAM anexado pela Receita/Fazenda no MVP.
- Credencial/link de validação do evento autorizado no backend.
- Planejar ajuste de 15 dias úteis e prazo interno de 2 dias úteis.

## Sexta-feira, 07/08/2026

Objetivo: fechar entrega para apresentação/homologação.

- Gerar documento de autorização em PDF/HTML imprimível.
- Gerar QR Code visual para a autorização.
- Criar tela de validação da credencial do evento.
- Marcar autorização como `DAM pendente na Receita Municipal` quando não isento.
- Marcar `Isento de DAM` para evento beneficente com declaração validada.
- Exibir prazo interno e destaque de demandas próximas de vencimento.
- Revisar responsividade web/mobile.
- Revisar textos, acentuação e nomes de secretarias.
- Rodar checklist manual.
- Preparar roteiro de demonstração.

## Segunda-feira, 10/08/2026

Objetivo: estabilizar para produção assistida.

- Corrigir feedback da homologação.
- Revisar segurança mínima.
- Configurar ambiente de produção/homologação.
- Definir backup e política de arquivos.
- Congelar versão `v0.1.0-mvp`.
- Planejar integração futura com DAM.
- Planejar envio de e-mails para secretarias, push, assinatura eletrônica e fluxo de vistoria com imagens/laudo.

## Fora do MVP

- IPTU.
- Notas fiscais.
- Alvará de construção.
- Alvará de funcionamento como solicitação própria.
- Integração automática com DAM.
- Aplicativos separados para cidadão e usuários internos.
- Substituir a Central de Eventos por fluxos isolados por secretaria.
