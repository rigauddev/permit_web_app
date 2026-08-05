# Roadmap de Entrega - MVP Alvará de Eventos

Considerando a data atual de quarta-feira, 05/08/2026, a meta realista é fechar um MVP demonstrável e homologável até sexta-feira, 07/08/2026, com estabilização até segunda-feira, 10/08/2026.

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

- Implementar cadastro PF/PJ.
- Implementar backend mínimo ou persistência provisória controlada.
- Implementar criação de solicitação com protocolo.
- Implementar upload/anexo real ou mock persistente validado.
- Gerar pendências por secretaria a partir das respostas.
- Implementar fila interna por secretaria.
- Implementar aprovação, recusa e pedido de correção.

## Sexta-feira, 07/08/2026

Objetivo: fechar entrega para apresentação/homologação.

- Gerar documento de autorização em PDF/HTML imprimível.
- Marcar autorização como `DAM pendente na Receita Municipal` quando não isento.
- Marcar `Isento de DAM` para evento beneficente com declaração.
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

## Fora do MVP

- IPTU.
- Notas fiscais.
- Alvará de construção.
- Alvará de funcionamento como solicitação própria.
- Integração automática com DAM.
- Aplicativos separados para cidadão e usuários internos.
