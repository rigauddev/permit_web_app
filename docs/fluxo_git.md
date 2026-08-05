# Fluxo Git

## Branches

- `main`: versão estável/homologada.
- `develop`: integração diária do MVP.
- `feature/<escopo>`: implementação pequena e revisável.
- `fix/<problema>`: correção pontual.
- `release/v0.1.0-mvp`: congelamento da entrega.

## Commits

Use mensagens curtas no padrão:

- `docs: cria roadmap do mvp`
- `feat: adiciona cadastro pf pj`
- `fix: corrige estado do formulario de alvara`
- `chore: configura gitignore`
- `test: adiciona casos do fluxo de evento`

## Fluxo recomendado até sexta

1. Trabalhar em `develop`.
2. Criar branches pequenas para cada entrega crítica.
3. Fazer merge em `develop` somente após rodar análise/testes básicos.
4. Na sexta, criar `release/v0.1.0-mvp`.
5. Corrigir somente bugs na release.
6. Fazer merge da release em `main`.
7. Criar tag `v0.1.0-mvp`.

## Checklist antes de merge

- `flutter analyze` sem erro bloqueante.
- Fluxo principal testado manualmente em Chrome.
- Formulário testado em largura mobile.
- Sem credenciais em código.
- Sem arquivos gerados/build no commit.
- Documentação atualizada quando a regra de negócio mudar.

## Comandos úteis

```bash
git status
git checkout -b develop
git checkout -b feature/alvara-evento-mvp
git add .
git commit -m "docs: organiza documentacao do mvp"
git checkout develop
git merge feature/alvara-evento-mvp
git checkout -b release/v0.1.0-mvp
git tag v0.1.0-mvp
```
