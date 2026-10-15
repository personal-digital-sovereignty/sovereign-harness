# Changelog — Sovereign Harness

## [Não lançado]

### Added
- `scripts/canario_claude.py`: canário real do guard no Claude Code headless — self-checks sem login (CI) + `--live` com veredito por estado do disco (bloquear/libera); 5 testes. Live pendente de `claude login` do dono (OAuth expirado aqui).

## [0.5.0] — 2026-10-15 — multi-stack, matriz macOS e exemplos

### Added
- Pre-push legado multi-stack: Rust/Node deixam de ser `elif` excludente; Python entra (pytest + ruff nos arquivos enviados). 4 testes herméticos com toolchains reais.
- Instalador leva `verificar_refs.py` e `verificar_adr.py` para `.harness/` e executa as cópias instaladas no gate pós-instalação (skill e comando `doc` referenciam o novo caminho).
- CI matriz ubuntu+macos (a bateria inteira roda nos dois SO por PR; toolchains reais instaladas).
- `docs/examples/`: UC1–UC6 + portabilidade macOS (achados sp-assets/E66) + matriz de certificação; README raiz referencia.

### Fixed
- `rm-symlink` liberava travessia no macOS (falso negativo): topo resolvido do git vs cwd lógico nunca casavam sob `/private` — raiz lógica via `.git`, provado com TMPDIR symlinkado.
- `mktemp` do pre-push com sufixo após os X falha no BSD; template termina em X.
- `documentation.py`: caminho resolvido comparado com raiz crua quebrava sob tmpdir symlinkado (matriz macos).

## [0.4.0] — 2026-10-15 — validador de índice/identidade de ADR

### Added
- `scripts/verificar_adr.py`: validador opcional de índice/identidade de ADR (follow-up do GAP-20261015-035) — ID numérico duplicado reprova nomeando os arquivos, índice sem linha e próximo-livre errado também; 7 testes. `ADR-INDEX.md` do próprio kit criado (o dogfood acusou a ausência); skill `doc-governance` referencia a ferramenta.

## [0.3.1] — 2026-10-15 — correção do vínculo de merge

### Added
- `merge_gate.sh` (perfil legado): gate `base` incondicional — re-lê head/base após os gates, re-lê `origin/main` no último instante antes do merge e confere pós-merge que o primeiro-pai da main nova é a base validada (squash/merge; `--rebase` avisa e pula). Teste hermético `test_merge_gate_base.sh` (T1–T5, `gh`/`ls-remote` dublês, repos reais; T4 cego no gate anterior).
- Instalador do perfil legado leva `test_merge_gate_base.sh` para `.agents/`; CI com `bash -n` nos hooks portáteis e etapa do vínculo merge-base.

## [0.3.0] — 2026-10-15 — contrato portátil de engenharia

### Added
- `install.sh`: `--docs-dir <dir>` (padrão `docs`, relativo, validado fail-loud) com reescrita das refs no `AGENTS.md` instalado; `--project-name <nome>` preenche o título; gate de refs pós-instalação sobre a árvore recém-escrita.
- Skill `doc-governance` + comando `doc`: classificação épico/GAP/insight/ADR, Epic↔ADR nos dois sentidos, `verificar_refs.py` como gate, guarda de índices e quarentena `_legacy`.
- Teste anti-divergência estendido: `doc-governance` tem seus marcadores de ciclo travados.
- Gates declarativos por argv/cwd e topologias repository/monorepo/meta-repository, com membros explícitos e testes reais sem remote ou branch main.
- Avaliação reproduzível da 0.1.0, contrato documental e registros em docs.
- Migração por mapa explícito, preservação de anexos e verificação de links locais; sete testes com Git real.
- Templates em docs para épicos, gaps, insights, ADRs, auditorias, arquitetura, runbooks e design system; skills de classificação e fechamento sincronizadas nos plugins.

### Changed
- `--docs-dir` passa a usar `docs` por padrão; a instalação cria PENDING, ROADMAP e CONCLUSION, além das categorias de engenharia.
- AGENTS separa política do projeto de método reutilizável; a validação executa somente gates declarados pelo projeto.
- Instalação padrão usa hooks portáveis; fluxo GitHub/Rust/Node e quadro compartilhado tornam-se perfil opt-in. Push recusa contrato não configurado, checkout rastreado sujo e refs diferentes do HEAD validado.
- Instalação usa docs/PENDING.md, docs/ROADMAP.md e docs/CONCLUSION.md; AGENTS distingue política do projeto de método reutilizável.
- README, comandos e skill de quadro distinguem mecanismo opcional de requisito universal; o roadmap raiz aponta para a fonte canônica em docs.

### Fixed
- Consulta de checks do adaptador GitHub recusa erros e ausência de evidência verde.
- Hooks Codex preservam caminhos com metacaracteres sem interpretação pelo shell.
- Verificador de links ignora exemplos literais em code spans.
- Guard recusa política inválida ou explicitamente ausente, com exit 2 no hook, sem retornar a defaults.
- Instalador recusa perfil TOML inválido, agente desconhecido e diretórios de destino por symlink, com controles negativos. Limites restantes da instalação estão no PENDING.

## [0.2.0] — 2026-10-15 — fase 1 agnóstica

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
