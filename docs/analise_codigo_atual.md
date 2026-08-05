# Análise do Código Atual

## Resumo executivo

O frontend Flutter já tem uma base visual e fluxo inicial para serviços, login, cadastro, dashboard de alvará e solicitação. O backend FastAPI, porém, ainda não está funcional. Para entregar o MVP de alvará de evento, o caminho é consolidar o fluxo existente, remover dependência de mocks no caminho principal e implementar persistência/workflow mínimo.

## O que já existe

- Login com tela amigável e MFA simulado.
- Cadastro de usuário externo.
- Home com acesso aos serviços.
- Tela de serviços da Receita Municipal.
- Entrada para `Solicitação de Alvará`.
- Dashboard de solicitações com status e detalhamento por pergunta/secretaria.
- Formulário em etapas com dados pessoais, anexos, dados do evento e perguntas.
- Seleção de arquivos com `file_picker`.
- Drawer com menus por tipo de usuário.

## Problemas que bloqueiam produção

1. `permit_system/main.py` não implementa API.
   Sem backend, não há autenticação real, persistência, upload, aprovação interna nem emissão confiável de autorização.

2. `AuthService` usa usuários mockados no cliente.
   Senhas, MFA e permissões estão no app. Isso serve para protótipo, mas não para produção.

3. O estado do formulário mistura campos.
   Em `permit_request_controller.dart`, dados básicos e dados do evento compartilham chaves como `-3`, `-4` e `-5`, causando sobrescrita.

4. As perguntas ainda não geram exigências reais.
   O sistema mostra perguntas, mas precisa transformar respostas em pendências para Meio Ambiente, Infraestrutura, DMTRAN, Vigilância Sanitária, Guarda Civil e Receita.

5. Permissões só existem na interface.
   O Drawer filtra menus, mas o backend precisa validar o acesso de cada perfil e secretaria.

6. Documento final ainda não existe.
   O MVP precisa gerar autorização com protocolo, status das anuências e indicação de DAM pendente ou isenção.

## Correções prioritárias

- Criar modelos fortes para `responsavel`, `evento`, `respostas`, `anexos` e `exigencias`.
- Criar lista completa de perguntas do alvará de evento.
- Implementar motor simples de regras:
  - som -> Meio Ambiente.
  - palco/gerador -> Infraestrutura.
  - trio elétrico -> DMTRAN.
  - bloqueio de via -> DMTRAN.
  - alimentação -> Vigilância Sanitária.
  - Guarda Civil -> Guarda Civil Municipal.
  - beneficente -> declaração e isenção de DAM.
- Criar backend mínimo com autenticação e CRUD de solicitações.
- Criar fila interna por secretaria.
- Criar tela/ação de análise: aprovar, recusar, pedir correção.
- Criar geração de documento final.

## Decisão sobre um app ou dois

Recomendação: um único app no MVP.

O código já caminha nessa direção com `userType`, `userProfile`, Drawer por perfil e rotas compartilhadas. Separar agora aumentaria o custo e atrasaria a entrega. O app único deve ter experiências diferentes por perfil:

- Cidadão: solicita e acompanha.
- Operador: analisa somente sua secretaria.
- Gestor: acompanha equipe/secretaria.
- Admin: configura usuários, secretarias e perguntas.

Depois do MVP, é possível separar áreas internas por módulo ou até criar um app interno sem descartar o backend.

## Risco de prazo

Entrega completa e segura até sexta-feira, 07/08/2026, é agressiva porque o backend está vazio. Para caber no prazo, a entrega deve ser um MVP assistido, com escopo fechado em alvará de evento e sem integração DAM automática.

## Resultado de verificação

Comando executado em `permit_app/permit_app/permit_web_app`:

```bash
flutter analyze
```

Resultado em 05/08/2026:

- 33 issues encontrados.
- Principais categorias: imports não usados, `print` em código de produção, uso de APIs depreciadas em Radio/FormField e uso de `BuildContext` após operações assíncronas.
- Não apareceu erro estrutural bloqueante, mas esses itens devem ser limpos antes da entrega de produção.
