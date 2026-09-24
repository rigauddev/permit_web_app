# Preparação para notificações push com Firebase Cloud Messaging

O sistema já mantém a notificação interna de aprovação ou recusa do Acesso à Orla. O FCM será a camada de entrega para o celular ou navegador quando o aplicativo estiver em segundo plano ou fechado.

## Arquitetura

1. A pousada aprova ou recusa a solicitação.
2. A API na VPS Lightsail registra a notificação no banco, que continua sendo a fonte de histórico.
3. A API envia uma cópia pelo Firebase Cloud Messaging ao dispositivo vinculado ao usuário.
4. Ao tocar na notificação, o app abre Acesso à Orla e consulta o status atualizado na API.

O FCM não altera regras de autorização: a API continua validando período de estadia, pousada/hotel e área autorizada.

## Configuração necessária

1. Criar o projeto no [Firebase Console](https://console.firebase.google.com/).
2. Cadastrar os apps Android, iOS e Web usando os identificadores definidos no projeto Flutter.
3. Android: baixar `google-services.json` e colocar em `android/app/`.
4. iOS: baixar `GoogleService-Info.plist` e adicionar ao alvo Runner no Xcode; habilitar Push Notifications e Background Modes. Também é necessário cadastrar a chave APNs no Firebase.
5. Web: gerar a chave pública VAPID no painel Cloud Messaging e configurar o service worker de push.
6. Na VPS, criar uma conta de serviço com permissão exclusiva para enviar mensagens FCM. O JSON dessa conta deve ficar fora do Git, em armazenamento seguro ou variável protegida do ambiente.
7. Adicionar os tokens de dispositivo na API, vinculados ao usuário autenticado, e remover tokens inválidos após resposta do FCM.

## Variáveis reservadas para a VPS

```dotenv
FCM_ENABLED=false
FCM_PROJECT_ID=
FCM_SERVICE_ACCOUNT_JSON=
FCM_WEB_VAPID_KEY=
```

Mude `FCM_ENABLED` para `true` somente depois de cadastrar os aplicativos, proteger a conta de serviço e testar envio para Android, iOS e navegador. Não versionar `google-services.json`, `GoogleService-Info.plist`, chave APNs, chave VAPID privada ou conta de serviço.

## Escopo inicial de push

- Solicitação de acesso à Orla aprovada.
- Solicitação de acesso à Orla recusada.
- Futuramente: pendências de alvará, vistorias e avisos de bloqueio de conta.

O Firebase Cloud Messaging não possui cobrança pelo envio de push. A VPS Lightsail continua responsável pela API e pela decisão de quais notificações devem ser enviadas. Consulte a [documentação oficial do FCM para Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) antes de inserir as credenciais.
