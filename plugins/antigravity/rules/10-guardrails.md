---
trigger: always_on
---

# Guardrails do método Sovereign (Antigravity)

O Antigravity não tem hook que bloqueie uma ação antes de executar, como o Claude Code, o Codex e o
OpenCode têm. Aqui as mesmas regras valem por instrução — e os gates do git (pre-commit, pre-push,
merge gate) continuam bloqueando de verdade no commit, no push e no merge.

**Antes de executar um comando ou editar um arquivo, confira se ele cai numa destas classes.** Se cair,
não execute: faça do jeito certo descrito na skill indicada, ou peça ao dono a exceção nominal.

| Regra | O que é proibido | Origem |
|---|---|---|
| `add-tudo` | `git add -A`/`.`/`-u` e `git commit -a` | AGENTS.md › Coexistência multi-agente, regra 3 |
| `no-verify` | `--no-verify` em commit/push/merge | AGENTS.md › CI e hooks: "não desative o hook" |
| `hooks-off` | `core.hooksPath` vazio ou `/dev/null` | CONCLUSION 2026-09-12: bypass por antecipação num merge |
| `skip-ci` | `[skip ci]` em mensagem de commit | ADR-041 item 8; AGENTS.md › CI regra 5 |
| `pkill-f` | `pkill -f` | skill medicao-comportamento-modelo §8; CONCLUSION 2026-10-08/10 |
| `stash-nu` | `git stash` sem mensagem/referência, `pop`, `clear` | pilha de stash compartilhada entre worktrees |
| `sudo` | `sudo`/`doas`/`pkexec` | AGENTS.md › Ferramentas de build, regra 5.4 |
| `segredo-env` | ler/imprimir `.env` | skill manuseio-segredos |
| `commit-protegida` | `git commit` em `main`/`master` | CONCLUSION 2026-09-07: HEAD movido por outra sessão |
| `worktree-main-local` | `git worktree add` a partir do `main` local | CONCLUSION 2026-09-09, erro #3 |
| `rm-symlink` | `rm`/`mv` que atravessa symlink para fora da árvore | CONCLUSION 2026-09-09, erro #1 |
| `npm-worktree` | `npm install/update` em worktree com `node_modules` symlinkado | CONCLUSION 2026-09-09, erro #2 |
| `merge-direto` | `gh pr merge` sem o merge gate | ADR-041 item 9; AGENTS.md › CI regra 5 |
| `quadro-copia` | editar a cópia não canônica do quadro | CONCLUSION 2026-09-12: incidente do rascunho |
| `gitconfig-global` | `git config --global user.*`, `gh auth setup-git` | AGENTS.md › Autoria; skill diagnostico-ssh-agent-git |
| `descarte-amplo` | `reset --hard`/`checkout .`/`clean -f` com algo a perder | skill vies-de-plausibilidade §7 |
| `descarte-arquivo` | `checkout --`/`restore` de arquivo com mudança não commitada (avisa) | skill vies-de-plausibilidade §7 |

Para conferir um comando antes de rodar (mesma decisão dos outros agentes):

```bash
python3 .harness/harness_guard.py checar --cmd "<comando>"
```

Skills do método: `.agents/skills/` (leia `disciplina-de-validacao` e `vies-de-plausibilidade`
no início de qualquer tarefa que termine em push).
