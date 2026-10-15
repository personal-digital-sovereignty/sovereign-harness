# UC5 — Meta-repo multi-agente (o caso Sovereign Pair)

> Medido em produção real: 9 releases do kit (0.1.0→0.4.0) e dezenas de PRs
> mergeados por este rito entre 2026-10-14 e 2026-10-15, vários agentes na
> mesma árvore.

## O circuito

```bash
# 1. Branch própria, commits atômicos; push roda os gates locais (.githooks)
# 2. PR + CI verde (2/2: testes multiplataforma + tipos)
# 3. Valida o RESULTADO do merge, não a branch (worktree irmão, descartável)
# 4. scripts/merge_gate.sh <PR>: gates + vínculo base (gate `base`
#    incondicional, re-leitura pré-merge, pai pós-merge) + merge com
#    --match-head-commit
```

Sem branch protection no servidor (GitHub Free + repos privados respondem
`403` — medido 2026-09-13), o merge vermelho só se impede no cliente. Sem
merge queue, a corrida base se estreita e se detecta alto — nunca se elimina
por cliente; isso está escrito no script, não só aqui.

## Quadro de trabalho

[`agents_work.md`](../../templates/docs/agents/agents_work.md) + [`quadro.sh`](../../templates/git/quadro.sh): quem está onde, paths sob
edição, branches (instalados como [`agents_work.md`](../../templates/docs/agents/agents_work.md) e [`quadro.sh`](../../templates/git/quadro.sh) dentro de `.agents/`). Exceção consciente documentada no próprio quadro — sem ele,
duas sessões descobriram o trabalho uma da outra por acidente (2026-09-07,
2026-09-09). Worktrees sempre de `origin/main`, nunca de `main` local.
