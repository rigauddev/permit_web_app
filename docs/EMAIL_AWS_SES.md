# E-mails transacionais com Amazon SES

Para o sistema municipal, a recomendação é usar o **Amazon SES** por SMTP. A API já possui envio SMTP; portanto, não será necessário trocar a lógica de e-mail quando a conta SES estiver pronta.

## Motivo da escolha

- Usa a mesma conta AWS da VPS Lightsail.
- Tem domínio/remetente verificado, métricas e controle de entrega.
- É cobrado por uso, sem contrato; a tabela oficial informa preço a partir de US$ 0,10 por mil e-mails no modo avulso. Consulte a [página oficial de preços do SES](https://aws.amazon.com/ses/pricing/) antes da publicação.

## Configuração na AWS

1. Abrir Amazon SES na região escolhida.
2. Verificar o domínio da Prefeitura e publicar os registros DNS solicitados: DKIM e SPF. Configurar DMARC conforme a política institucional.
3. Solicitar saída do sandbox para envio aos cidadãos.
4. Criar credenciais SMTP exclusivas para a API, sem reutilizar usuário AWS.
5. Incluir as variáveis SMTP no ambiente seguro da VPS, usando `.env.lightsail.example` apenas como referência.
6. Definir `PREFEITURA_LOGO_URL` como URL HTTPS pública para a logo institucional usada nos e-mails.

## Modelos editáveis

Em **Gestão do Sistema → Modelos de e-mail**, o administrador edita Boas-vindas, Conta bloqueada e Recuperação de senha. Cada modelo tem assunto, cabeçalho, corpo, rodapé e seleção entre logo do sistema ou imagem personalizada. Os marcadores disponíveis são `{{nome}}` e, em recuperação de senha, `{{codigo}}`.

O e-mail de boas-vindas é enviado após o cadastro quando o SMTP está configurado. A tela já armazena os demais modelos para os fluxos de bloqueio e recuperação.
