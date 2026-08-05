lib/
├── core/                          # Configurações globais, temas, rotas, serviços
│   ├── routes/
│   ├── themes/
│   ├── network/                    # Exemplo: interceptadores, api_client
│   └── utils/                      # Funções genéricas, helpers globais
│
├── data/                           # Camada de acesso a dados
│   ├── models/                     # Modelos (DTOs, entidades de banco, etc)
│   ├── repositories/               # Interfaces ou implementações de Repos
│   └── datasources/                # APIs, LocalStorage, etc
│
├── domain/                         # Regras de negócio, Entities, Use Cases
│   ├── entities/
│   └── usecases/
│
├── features/                       # Pasta por MÓDULO (feature modularizada)
│   └── permit_request/             # Exemplo: módulo de Solicitação de Alvará
│       ├── controller/             # Controladores, StateNotifiers, Providers
│       ├── model/                  # Modelos específicos do módulo
│       ├── ui/                     # Páginas, Widgets específicos dessa feature
│       └── widgets/                # Widgets pequenos reutilizáveis internos do módulo
│
├── presentation/                   # Pages globais (ex: Login, Home, Splash)
│   └── pages/
│
├── shared/                         # Widgets genéricos reaproveitáveis (ex: Botões custom, Loadings)
│   └── widgets/
│
├── l10n/                           # Traduções (se usar)
│
└── main.dart                       # Entry Point
