# Roadmap de Entrega

Considerando a data atual de quinta-feira, 06/08/2026, a meta realista é fechar um MVP demonstrável e homologável até sexta-feira, 07/08/2026, com correções finais e estabilização até segunda-feira, 10/08/2026.

Este roadmap deve ser lido junto com:

- `docs/prompts_master.md`
- `docs/regras_central_eventos_ata.md`
- `docs/tarefas_execucao_mvp.md`
- `docs/arquitetura_dam_qrcode_validacao_evento.md`

## Decisão de escopo

Primeira função em produção: solicitação de alvará de festa/evento.

O processo deve seguir a Central de Eventos definida em ATA:

- Secretaria de Desenvolvimento Econômico centraliza o processo.
- Secretarias e órgãos analisam eletronicamente suas exigências.
- Solicitação deve respeitar antecedência mínima de 15 dias úteis.
- Cada secretaria deve ter prazo interno de 2 dias úteis para análise.
- Receita/Fazenda atua no DAM após documentação e anuências completas.

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

- Backend FastAPI com autenticação, MFA, seeds e solicitações reais.
- Cadastro PF/PJ com validação de e-mail.
- Criação de solicitação com protocolo.
- Geração de pendências por secretaria a partir das respostas.
- Fila interna por secretaria.
- Aprovação, recusa, pedido de correção e comentários.
- DAM anexado pela Receita/Fazenda no MVP.
- Credencial/link de validação do evento autorizado no backend.
- Atualizar regras para 15 dias úteis e planejar SLA interno de 2 dias úteis.

## Sexta-feira, 07/08/2026

Objetivo: fechar entrega para apresentação/homologação.

- Gerar documento de autorização em PDF/HTML imprimível.
- Gerar QR Code visual no documento e na tela da autorização.
- Criar tela de validação de credencial do evento.
- Marcar autorização como `DAM pendente na Receita Municipal` quando não isento.
- Marcar `Isento de DAM` para evento beneficente com declaração validada.
- Ajustar frontend para refletir Central de Eventos e coordenação pela Secretaria de Desenvolvimento Econômico.
- Exibir prazos e alertas iniciais para análise interna de 2 dias úteis.
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
- Planejar integração futura com DAM, e-mail, push, assinatura eletrônica e armazenamento de imagens.
- Planejar fluxo completo de vistoria com imagens e laudo técnico.

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
- Geração de QR Code e validação da credencial.
- Revogação de credencial e bloqueio de validação.

## Prioridade de correções no código atual

1. Criar documento final de autorização.
2. Gerar QR Code visual a partir da credencial do backend.
3. Criar tela de validação de credencial.
4. Ajustar regra de antecedência para 15 dias úteis no frontend/backend.
5. Criar prazo interno de 2 dias úteis por exigência/secretaria.
6. Criar visão gestor/admin para todas as secretarias.
7. Implementar upload binário validado para anexos e DAM.
8. Criar logs de auditoria.
9. Melhorar layout responsivo do formulário, dashboard e fluxo interno.
