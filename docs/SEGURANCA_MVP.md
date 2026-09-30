# Revisão de segurança do MVP

## Controles verificados

- JWT com expiração distinta para web e aplicativo.
- Senhas armazenadas com hash bcrypt.
- MFA disponível para usuários.
- Rotas administrativas protegidas por papel no backend.
- Gestão da Orla limitada às secretarias responsáveis.
- Consulta, leitura de placa, registro de entrada e relatórios da Orla exigem autenticação e perfil autorizado.
- Histórico de veículo valida propriedade ou perfil de fiscalização.
- Gestão de usuários, permissões, secretarias, serviços e aprovação de banners exige perfil administrativo.
- CORS limitado aos domínios configurados e às redes privadas usadas no desenvolvimento.
- Upload valida extensão e tamanho máximo.
- Credenciais e arquivos `.env` reais permanecem fora do Git.

## Rotas públicas intencionais

- Login, MFA, verificação de e-mail e cadastro inicial.
- `GET /health`, que retorna apenas `{"status":"ok"}` e não consulta o banco.
- Validação pública de credencial de evento por código e token.
- Catálogo público de pousadas aprovadas, limitado a identificador, nome e indicador de Orla.
- Sugestão de nova pousada durante o cadastro. A sugestão não autoriza acesso automaticamente.
- Upload dos documentos necessários ao cadastro antes da criação da sessão.

## Riscos que ainda exigem tratamento antes da produção

### Alta — documentos acessíveis por URL opaca

Os arquivos usam nomes aleatórios e não possuem listagem de diretório, mas o servidor de arquivos ainda entrega o conteúdo quando alguém conhece a URL completa. Antes da produção, documentos pessoais devem usar armazenamento privado e download autenticado, com validação do proprietário, papel e secretaria.

### Média — proteção contra abuso em rotas públicas

Login, verificação de e-mail, cadastro, sugestão de pousada e upload público precisam de rate limiting por IP e identificador, além de limites operacionais e monitoramento.

### Média — auditoria

Ações administrativas, aprovação de banners, alteração de permissões, validações da Orla e downloads de documentos sensíveis devem gerar logs de auditoria com usuário, data, objeto e ação, sem registrar senha, token, documento completo ou conteúdo anexado.

## Critérios obrigatórios para homologação externa

- Configurar `SECRET_KEY` forte e exclusiva do ambiente.
- Manter `RUN_SEED=false` e remover contas de teste.
- Usar HTTPS.
- Configurar `CORS_ORIGINS` apenas com os domínios oficiais.
- Armazenar documentos em área privada.
- Ativar rate limiting nas rotas públicas.
- Executar testes de autorização horizontal e vertical por perfil e secretaria.
