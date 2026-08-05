# Roadmap de Entrega

Considerando a data atual de quarta-feira, 05/08/2026, a meta realista é fechar um MVP demonstrável e homologável até sexta-feira, 07/08/2026, com correções finais e estabilização até segunda-feira, 10/08/2026.

## Decisão de escopo

Primeira função em produção: solicitação de alvará de festa/evento.

Ficam fora do MVP:

- IPTU.
- Notas fiscais.
- Alvará de construção.
- Alvará de funcionamento como solicitação própria.
- Integração automática com sistema de DAM.
- Aplicativos separados para cidadão e interno.

## Quarta-feira, 05/08/2026

Objetivo: travar escopo e remover riscos óbvios.

- Consolidar documentação de produto, técnica, roadmap e prompts.
- Inicializar controle de versão local.
- Definir modelo de dados do MVP.
- Corrigir estado do formulário para separar dados do responsável, evento, respostas e anexos.
- Trocar perguntas mockadas por uma lista completa do fluxo de evento.
- Esconder serviços fora do MVP ou marcá-los como indisponíveis.
- Definir visual e navegação mobile/web para o fluxo principal.

## Quinta-feira, 06/08/2026

Objetivo: fazer o fluxo funcionar de ponta a ponta.

- Implementar backend mínimo ou persistência provisória controlada.
- Criar cadastro PF/PJ com CPF/CNPJ.
- Implementar login real ou ambiente controlado com aviso claro de homologação.
- Implementar criação de solicitação com protocolo.
- Implementar upload/anexo real ou mock persistente com validação.
- Gerar pendências por secretaria a partir das respostas.
- Implementar fila interna por secretaria.
- Implementar aprovação, recusa e pedido de correção.

## Sexta-feira, 07/08/2026

Objetivo: fechar entrega para apresentação/homologação.

- Gerar documento de autorização em PDF/HTML imprimível.
- Marcar autorização como "DAM pendente na Receita Municipal" quando não isento.
- Marcar "Isento de DAM" para evento beneficente com declaração.
- Revisar responsividade web/mobile.
- Revisar textos, acentuação e nomes de secretarias.
- Rodar testes básicos e checklist manual.
- Preparar roteiro de demonstração.

## Segunda-feira, 10/08/2026

Objetivo: estabilizar para produção assistida.

- Corrigir feedback da homologação.
- Revisar segurança mínima.
- Configurar ambiente de produção/homologação.
- Definir backup e política de arquivos.
- Congelar versão `v0.1.0-mvp`.
- Planejar integração futura com DAM.

## Checklist de demonstração

- Cadastro de cidadão PF.
- Cadastro de cidadão PJ.
- Login.
- Nova solicitação de alvará de evento.
- Anexo de documentos obrigatórios.
- Perguntas: som, palco/gerador, trio elétrico, bloqueio de via, alimentação, Guarda Civil, brigadista e evento beneficente.
- Dashboard do cidadão com status.
- Login de operador de uma secretaria.
- Operador vê somente sua fila.
- Operador aprova ou pede correção.
- Geração de autorização final.

## Prioridade de correções no código atual

1. Corrigir colisão de campos no estado do formulário.
2. Remover mocks de login/usuários do caminho de produção.
3. Criar camada de API no Flutter.
4. Implementar backend mínimo.
5. Criar workflow por secretaria.
6. Melhorar layout responsivo do formulário e dashboard.
7. Criar documento final de autorização.
