# UC3 — Frontend Node/Svelte

> Medido: despacho + escopo em sandbox Linux, 2026-10-15; regras citadas vêm
> dos comentários do próprio `pre-push` (incidentes de 2026-09-06).

## Instalar

```bash
./install.sh /caminho/web --git-profile github-rust-node
git -C /caminho/web config core.hooksPath /caminho/web/.githooks
```

Detecção por `package.json`. O push roda:

```
✅ types   # npm run check --silent (svelte-check)
✅ test    # npm test --silent
✅ lint    # prettier --check (só nos arquivos enviados, .md fora)
```

## Duas decisões que parecem detalhe e não são

- **`npm run check`, nunca `npx tsc --noEmit`**: o tsc cru não conhece as
  runas do Svelte 5 e acusa `Cannot find name '$state'` em código correto
  (medido 2026-09-06).
- **Prettier pelo binário local** (`node_modules/.bin/prettier`), nunca `npx`
  cru (pode resolver outra versão e divergir do projeto). Sem prettier
  instalado, o gate vira `n/a` avisado — não verde silencioso.
- **`.md` fora do prettier de propósito**: CHANGELOG/README já eram
  não-conformes em `main`; formatar arrastaria 20–45 linhas de entradas
  antigas para dentro de commit alheio.
