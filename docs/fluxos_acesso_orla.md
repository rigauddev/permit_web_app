# Fluxos operacionais — Acesso à Orla de Guaibim

Este material registra o fluxo efetivo do MVP. A aprovação da pousada/hotel é obrigatória para turista que seleciona uma hospedagem; a fiscalização ainda valida período da estadia e situação do estabelecimento na área autorizada.

## Turista — pessoa física

```mermaid
flowchart TD
  A[Inicia cadastro] --> B[Seleciona Turista e Pessoa física]
  B --> C[Informa dados pessoais, CPF, e-mail único e senha]
  C --> D[Seleciona pousada/hotel ou informa hospedagem]
  D --> E[Seleciona período da estadia]
  E --> F[Cadastra veículo: placa, marca, modelo e cor]
  F --> G[Solicita acesso à Orla]
  G --> H[Compartilha link da solicitação com a pousada pelo WhatsApp]
  H --> I{Pousada aprova?}
  I -->|Sim| J[Status aprovado]
  I -->|Não| K[Status recusado]
  J --> L[Entrada validada pelo fiscal: período + pousada na Orla + QR/placa]
```

## Turista — pessoa jurídica

```mermaid
flowchart TD
  A[Inicia cadastro] --> B[Seleciona Turista e Pessoa jurídica]
  B --> C[Informa razão social, CNPJ, telefone, e-mail único e senha]
  C --> D[Informa pousada/hotel e período de estadia]
  D --> E[Cadastra veículo]
  E --> F[Solicita acesso e compartilha o link]
  F --> G{Pousada aprova?}
  G -->|Sim| H[Status aprovado e acesso sujeito ao período]
  G -->|Não| I[Status recusado]
```

## Pousada/hotel cadastrando hóspede

```mermaid
flowchart TD
  A[Conta da pousada/hotel] --> B[Meus serviços > Hóspedes]
  B --> C{Origem do hóspede}
  C -->|Solicitação do turista| D[Abre Solicitações de acesso à Orla]
  D --> E[Confere hóspede, veículo e período]
  E --> F{Aprovar?}
  F -->|Sim| G[Status aprovado]
  F -->|Não| H[Status recusado]
  C -->|Cadastro pela pousada| I[Cadastra hóspede ou excursão]
  I --> J[Informa veículo e período]
  J --> K[Marca Liberar acesso à Orla]
  K --> L[Gera QR Code]
  L --> M[Envia QR Code e link do sistema pelo WhatsApp]
  G --> N[Fiscal valida QR/placa, período e pousada autorizada]
  M --> N
```

Os arquivos para apresentação ficam em `docs/arquivos/fluxos_acesso_orla.pptx` e `docs/arquivos/fluxos_acesso_orla.pdf`. O PowerPoint usa formas editáveis.
