# Regras da Central de Eventos - ATA 24/02/2025

Fonte: `ATA_CENTRAL_DE_EVENTOS_PMV_assinado_assinado.md`.

Este documento resume as instruções de negócio que devem orientar o roadmap, as tarefas e as próximas implementações do sistema de Alvará de Eventos.

## Diretriz central

O processo de autorização de eventos deve ser simplificado, digitalizado e centralizado para reduzir deslocamentos do cidadão entre secretarias.

## Coordenação do processo

- A Secretaria de Desenvolvimento Econômico centraliza o processo de autorização de eventos.
- As demais secretarias e órgãos atuam de forma eletrônica dentro do fluxo.
- A Receita/Fazenda só deve atuar na emissão/validação do DAM depois que a documentação e as anuências aplicáveis estiverem completas.
- O cidadão deve acompanhar o processo em um único sistema, sem precisar entregar a mesma solicitação em várias secretarias.

## Prazos

- A solicitação deve ser feita com antecedência mínima de 15 dias úteis antes do evento.
- Cada secretaria/órgão responsável deve ter prazo interno de 2 dias úteis para analisar a demanda.
- O sistema deve destacar solicitações próximas do vencimento do prazo interno.

## Exigências mínimas iniciais

- Ofício ou ficha de solicitação.
- Nome do solicitante/responsável.
- CPF ou CNPJ.
- Endereço residencial ou sede da empresa.
- Telefone e e-mail de contato.
- Nome do evento.
- Data do evento.
- Local/endereço do evento.
- Expectativa de público.
- Horário previsto de início e término.
- RG/CPF ou documento equivalente.
- Comprovante de residência.
- Alvará de funcionamento do local, quando houver.

## Exigências condicionais

- Som: termo de responsabilidade ambiental pela Secretaria de Meio Ambiente.
- Local fixo sem alvará de funcionamento: solicitar regularização do local.
- AVCB: responsabilidade do solicitante, com fiscalização/validação pela Infraestrutura.
- Palco, gerador ou estrutura: ART de responsabilidade do solicitante e vistoria pela Infraestrutura.
- Evento particular de médio/grande porte em local fixo: planta baixa.
- Uso de via pública, fechamento de rua ou desvio de trânsito: autorização do DMTRAN e croqui/mapa.
- Trio elétrico: vistoria do veículo, CNH do condutor e mapa do circuito pelo DMTRAN.
- Alimentação: certificado/validação da Vigilância Sanitária.
- Ambulância: ofício à Secretaria de Saúde.
- Guarda Civil Municipal: ofício solicitando presença, quando necessário.
- Brigadista: contratação sob responsabilidade do solicitante, quando exigido.
- Evento beneficente: declaração da instituição beneficiada para isenção de DAM.

## DAM e autorização final

- Após todas as anuências, a Secretaria de Desenvolvimento Econômico encaminha/solicita a emissão do DAM à Receita/Fazenda.
- No MVP, o DAM é gerado fora do sistema e anexado à solicitação aprovada.
- Depois do DAM anexado ou da isenção validada, o sistema pode emitir a autorização final.
- A autorização deve ficar em nome do responsável pelo evento.
- A autorização deve ser apresentada às autoridades fiscais quando solicitada.

## Fiscalização e validação

- A autorização final deve ter credencial/QR Code de validação.
- A leitura do QR Code deve exibir dados do evento, status das anuências, status do DAM ou isenção e anexos autorizados.
- A equipe de plantão/fiscalização deve conseguir validar se o evento está autorizado, revogado, expirado ou pendente.

## Implicações para o produto

- O sistema deve tratar a Central de Eventos como fluxo único, com filas por secretaria.
- O dashboard interno deve evidenciar prazo interno de 2 dias úteis por órgão.
- A tela do cidadão deve deixar claro quais documentos e ações são responsabilidade dele.
- A tela interna deve deixar claro o que cada secretaria precisa validar, aprovar, recusar ou solicitar correção.
- O roadmap deve priorizar: documento final, QR visual, tela de validação, prazos internos, notificações por e-mail e fluxo de vistoria.
