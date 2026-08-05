# Visão Geral - Alvará de Eventos

## Objetivo

Digitalizar o fluxo municipal de autorização de eventos, começando pela solicitação de alvará de festa/evento. O sistema deve reduzir ida e volta presencial, orientar o cidadão sobre exigências por tipo de evento e dar às secretarias uma fila clara de análise.

## Recomendação de arquitetura de produto

Para a entrega de sexta-feira, 07/08/2026, e estabilização até segunda-feira, 10/08/2026, a recomendação é manter um único app web/mobile com perfis e permissões.

Motivos:

- Menor tempo de entrega.
- Um único login e uma única base visual.
- Usuário externo e usuário interno compartilham o mesmo processo, mas veem telas diferentes.
- Permite separar por secretaria sem duplicar frontend.

Separar em dois apps só deve virar prioridade quando houver volume alto de uso interno, necessidade de publicação mobile separada ou políticas muito diferentes de segurança/distribuição.

## Perfis

- `cidadao`: usuário externo, pessoa física ou jurídica.
- `operador_secretaria`: analisa solicitações destinadas à sua secretaria.
- `gestor_secretaria`: acompanha e redistribui solicitações da secretaria.
- `admin`: gerencia usuários, secretarias, perguntas, permissões e configuração do serviço.

## Secretarias e órgãos envolvidos

- Secretaria de Desenvolvimento Econômico: protocolo inicial e coordenação do processo.
- Secretaria de Meio Ambiente: termo de responsabilidade ambiental quando houver som.
- Secretaria de Infraestrutura: vistoria de palco, gerador e estrutura.
- DMTRAN/Mobilidade e Ordem Pública: trio elétrico, motorista, mapa de circuito, uso ou bloqueio de vias.
- Vigilância Sanitária/Secretaria de Saúde: alimentação, equipamentos e instalações.
- Guarda Civil Municipal: presença solicitada por ofício quando necessário.
- Receita Municipal: DAM e liberação final após pagamento ou isenção.

## Fluxo do cidadão

1. Cadastrar conta como pessoa física ou jurídica.
2. Entrar no sistema.
3. Selecionar `Solicitação de Alvará > Alvará de Evento`.
4. Preencher dados do responsável.
5. Anexar RG/CPF ou documento equivalente, comprovante de residência e alvará de funcionamento do local.
6. Preencher dados do evento.
7. Responder perguntas condicionais.
8. Conferir exigências geradas por secretaria.
9. Enviar solicitação.
10. Acompanhar status, observações e pedidos de correção.
11. Receber autorização condicionada à emissão/pagamento do DAM ou isenção.

## Dados mínimos da solicitação

- Nome do solicitante/responsável.
- CPF ou CNPJ.
- Endereço residencial ou sede da empresa.
- Telefone e e-mail.
- Nome do evento.
- Data do evento.
- Local/endereço do evento.
- Expectativa de público.
- Horário previsto de início e término.
- Indicador de evento beneficente e instituição beneficiada, quando aplicável.

## Regras iniciais

- Solicitação deve ser feita com pelo menos 15 dias de antecedência.
- Evento com som exige Meio Ambiente.
- Evento com palco ou gerador exige Infraestrutura.
- Evento com trio elétrico exige DMTRAN, vistoria do veículo, CNH do motorista e mapa do circuito.
- Uso ou bloqueio de vias municipais exige DMTRAN.
- Evento com alimentação exige Vigilância Sanitária.
- Necessidade de Guarda Civil exige ofício específico.
- Brigadista deve ser contratado pelo responsável quando exigido.
- Evento beneficente é isento de DAM mediante declaração de instituição beneficiada.
