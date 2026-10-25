# Changelog — Sovereign Harness

## [0.7.1] — 2026-10-25 — lição corrigida do `set -e` e o padrão perigoso provado

### Changed
- Skill `estado-compartilhado-multi-agente` §7: a lição "no shell de ferramenta do agente o `set -e` pode não abortar" foi **desmentida como regra de harness** e reescrita pelo motivo correto. O mesmo comando medido nos dois lados deu resultados opostos — no Claude Code (2026-10-23) `set -e; false; echo x` imprimiu `x`; no OpenCode (2026-10-25) **abortou com rc=1**, inline, via `bash -c`, em arquivo `.sh` e sob o `rtk` — porque o shell ignora `errexit` por especificação dentro de `if`, `&&`/`||`, `while`/`until` e substituição de comando, que é como um harness embrulha o comando. `set -e` não é contrato entre harnesses; o `&&` vale nos dois. A rede real do passo 3 é a guarda da ref. Validação no projeto de origem: 26 corridas do `test_ref_main.sh` verdes.

- Skills `vies-de-plausibilidade` (§4) e nota do `pre-commit`: ressala de medição nas taxas de falsa negativa do `grep -q` sob `pipefail` — o mecanismo (SIGPIPE ao comando de leitura rápida) reproduz sempre; os números (152/300, 200/200) eram **uma rodada observada**, de corrida: revalidados no mesmo host, 0–52/300 e 0–1/30, e só o caso de lista grande foi determinístico (94 KB com o match na 1ª linha: 50/50 com `printf`, 0/50 com here-string). Cite o mecanismo; trate cada número como rodada.

### Added
- `templates/git/test_ref_main.sh`: asserção P3 — nenhum `printf ... | grep -q` (em linha de código; comentários não contam) pode voltar ao `pre-commit`/`reference-transaction`. Prova da forma, porque o mutante M6 na guarda do quadro é inalcançável pelo hook em funcionamento normal (lista grande na `main` é barrada antes pelos gates `main`/`outros`) e o comportamento na corrida não é determinístico; no arranjo grande do P2, o mutante no gate de skills já deixa a skill quebrada entrar. Reprovado no negativo: com o `grep -qxF "$QUADRO" <<<"$staged"` revertido ao pipeline numa cópia mutada, o P3 falha (2026-10-25).

## [0.7.0] — 2026-10-24 — guarda da main do repositório de coordenação e saúde do quadro

### Added
- Perfil legado: `templates/git/reference-transaction`, guarda da ref `main` do repositório de coordenação. Cobre o que o `pre-commit` não vê (`merge`, `update-ref`, `reset`): recusa deleção e recuo da `main` (comparação contra a ref atual — o "old" do stdin vem zerado em atualização forçada) e árvore nova que reprove os verificadores de skills (`check_skills.py --rev`, se o projeto o tiver) e de links (`check_doc_refs.py --root`, senão `.harness/documentation.py`), rodados sobre um export do commit, não sobre o disco. Num `merge` recusado o git já escreveu a árvore de trabalho: a recusa lista os arquivos e o `git restore --source=main` seletivo, nunca `reset --hard`. Exceções `HARNESS_SKIP=main-ref` e `docrefs`. Instalado pelo perfil legado com `.agents/test_ref_main.sh` (A1–A10, B1–B4, Q1–Q2, P1–P2), que também roda no CI e a partir da instalação.
- Perfil legado, `pre-commit`, gate `main`: na `main` só se commita o quadro e a conclusão de merge (`HARNESS_SKIP=main`). A conclusão de merge que só incorpora o quadro idêntico ao da `main` deixa de ser barrada como edição do quadro.
- `quadro.sh saude`: acusa arquivo alterado ou novo no checkout principal sem declaração em "Paths sob edição" de "Em andamento" (caminho, nome+diretório pai, ou diretório declarado; o próprio quadro não conta). Teste S6a–S6e.
- `quadro.sh saude [--estrito]`: relatório do que está fora da branch principal no repositório de coordenação — branches com conteúdo pendente (patch sem equivalente, via `git cherry`), separando as que só faltam apagar e as órfãs sem entrada ativa no quadro — e das entradas de "Em andamento" sem data nova há mais de `QUADRO_DIAS_PARADA` (3) dias. Não bloqueia; `--estrito` sai 1. `quadro.sh ler` imprime o relatório em stderr ao final (stdout intacto; `QUADRO_SEM_SAUDE=1` desliga). Teste hermético S0–S5 em `templates/git/test_quadro.sh`, provado no negativo (contra o helper anterior as asserções positivas reprovam).

### Fixed
- `test_ref_main.sh`: o commit de 6000 arquivos do P2 disparava um `gc --auto` destacado que sobrevivia ao teste e escrevia `objects/info/packs` enquanto o `trap` apagava o diretório — o `rm` falhava e sobrava lixo no `/tmp` (2 de 3 rodadas). O repositório descartável agora tem `gc.auto 0` e `maintenance.auto false`; 0 de 6 rodadas com resíduo.
- `test_quadro.sh`: a asserção "S6a `--estrito` reprova edição não declarada" passava também com o helper sem o alerta, porque as entradas paradas do S4 já reprovavam; agora roda com `QUADRO_DIAS_PARADA` alto, com linha de base que precisa passar antes do arquivo solto, e reprova contra o helper anterior. As asserções por `echo "$saida" | grep -q` (18, mais o `main_tem` e o S5) viraram here-string: numa asserção negativa (`grep -q X && nok || ok`) a falsa negativa do pipe sob `pipefail` vira `ok`. O S6d usava `sed -i` sem sufixo, só do GNU; no macOS o preparo falhava (pego pelo CI do #16).
- Perfil legado, `pre-commit`: `produtor | grep -q` sob `pipefail` dava falsa negativa — o `grep -q` sai cedo, o produtor leva SIGPIPE e o pipeline conta como falha. Medido no projeto de origem: `env | grep -q` ignorava `HARNESS_SKIP=docrefs` em 152/300 execuções; com lista grande, `printf | grep -q` errou 200/200 (gate pulado). Trocado por here-string e `case`; o mesmo padrão saiu do `install.sh`. Scripts auxiliares do hook resolvidos pelo diretório do hook, não pelo CWD. Regressão P1/P2 reprova contra a versão anterior.

### Changed
- Skill `estado-compartilhado-multi-agente`: §7, publicar na `main` do repositório de coordenação com o checkout principal sujo de outra sessão (update-ref com CAS + restore seletivo + patch), encadeado com `&&` porque no shell de ferramenta do agente o `set -e` pode não abortar (medido); efeito do merge recusado pela guarda.
- Skill `vies-de-plausibilidade` §4: o filtro pode estar no próprio gate (`produtor | grep -q` sob `pipefail`).
- Skill `quadro-de-trabalho` e `/quadro`: guardas novas e edição não declarada na `saude`.
- Skill `encerrar-documentacao`: passo 7, "publique e prove" — commit em branch não é entrega; a unidade encerrada entra na linha principal no mesmo passo e se prova com `git merge-base --is-ancestor`, conferindo a `saude` do quadro. Passo 5: documento já citado fora do repositório que muda de lugar ganha registro origem → destino, sem reescrever a referência histórica. Passo 6: inclui verificadores entre repositórios.
- Skill `quadro-de-trabalho` e comando `/quadro`: documentam a `saude` e o fechamento pela branch principal.

## [0.6.0] — 2026-10-15 — canário Claude + verifiers instalados

### Added
- `scripts/canario_claude.py`: canário real do guard no Claude Code headless — self-checks sem login (CI) + `--live` com veredito por estado do disco (bloquear/libera); 5 testes. Live pendente de `claude login` do dono (OAuth expirado aqui).
- Instalador leva `verificar_refs.py` e `verificar_adr.py` para `.harness/` e executa as cópias instaladas no gate pós-instalação (skill e comando `doc` referenciam o novo caminho).

## [0.5.0] — 2026-10-15 — multi-stack, matriz macOS e exemplos

### Added
- Pre-push legado multi-stack: Rust/Node deixam de ser `elif` excludente; Python entra (pytest + ruff nos arquivos enviados). 4 testes herméticos com toolchains reais.
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
