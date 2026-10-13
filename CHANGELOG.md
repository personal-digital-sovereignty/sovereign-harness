# Changelog — Sovereign Harness

## [0.1.0] — 2026-10-13 — primeira publicação

Publicado como repositório público `personal-digital-sovereignty/sovereign-harness`, licença MIT.

### Added
- `core/harness_guard.py`: guard do agente com 17 regras (origem registrada, escape nominal, severidade por regra, registro JSONL sem comando em claro, subcomandos `hook`, `checar`, `contexto`, `regras`, `config`).
- 12 skills de método e 5 comandos.
- Plugins: Claude Code (guard + método, marketplace), Codex (skills + hooks de projeto), OpenCode (plugin TS), Antigravity (regras e workflows).
- Templates de git (pre-push com radar dirigido por `.harness/radar.tsv`, pre-commit do quadro, merge gate, helper do quadro) e de documentação.
- `install.sh` idempotente e `scripts/sincronizar.py` com modo `--verificar`.
- Convenção `.agents/`: skills sempre em `.agents/skills/`; com o Claude Code, `.claude/skills → ../.agents/skills` (o Claude só descobre esse caminho e segue o symlink — medido); regras e workflows do Antigravity em `.agents/`; `--sem-skills`.
- Guard recalibrado contra 38.131 ações reais do projeto de origem: três falsos positivos corrigidos; descarte de trabalho julgado pelo efeito (`descarte-amplo` bloqueia, `descarte-arquivo` avisa).
- CI em runner hospedado: testes, sincronia, shell e tipos do plugin do OpenCode (tsc contra `@opencode-ai/plugin` 1.18.25).

### Validação
- 40 testes (guard em repositórios git reais, instalador rodando de verdade, integridade do kit); mutação de regras e do instalador reprova a suíte.
- Canários reais: Codex e OpenCode bloquearam `git stash`; OpenCode liberou `git status`. Claude Code: manifestos validados, canário headless pendente.
- Calibração sobre 38.131 ações reais do projeto de origem: três falsos positivos corrigidos; descarte julgado pelo efeito.
