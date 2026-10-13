# Instruções para agentes de IA — <nome do projeto>

> Fonte única das instruções do projeto. `CLAUDE.md` e `GEMINI.md` são symlinks para este arquivo;
> o Antigravity o recebe pela regra `always_on` em `.agents/rules/`; Codex e OpenCode o leem nativamente.
> Preencha os campos `<...>`. Mantenha curto: o que é verificável vira gate, o que é julgamento vira skill.

## Leitura obrigatória

- Arquitetura: `<project_docs/ARQUITETURA.md>`
- Pendências: `project_docs/PENDING_GAPS_AND_ROADMAP.md` — só o que está aberto.
- Histórico: `project_docs/CONCLUSION_ROADMAP_AND_GAPS.md` — o "porquê" de tudo que já foi decidido ou entregue.
- Quadro de trabalho: `<caminho absoluto do .agents/agents_work.md no diretório principal>` (skill `quadro-de-trabalho`).

## Comunicação

- Idioma: `<idioma>`. Técnico e direto, sem bajulação.
- Senso crítico: revise a própria sugestão contra o histórico do projeto antes de propor.

## Segurança e soberania

1. **Nenhum fallback silencioso.** Falhou: logue e estoure o erro (fail-loud).
2. **Credenciais** só por ambiente/cofre; nunca no código, em fixture, commit, PR ou log (skill `manuseio-segredos`).
3. **Dependência de sistema ausente**: reproduza o erro exato, identifique o pacote, entregue o comando ao dono. O agente não roda `sudo`.

## Testes e validação

1. Testes unitários, de integração, E2E e de usabilidade **sempre** executados. Nunca mocke o que pode rodar localmente (skill `validacao-real-sem-mock`).
2. E2E de interface com `<Playwright>`.
3. Todo verificador novo é provado no sentido negativo (skill `disciplina-de-validacao`).
4. Bateria completa antes de qualquer push — aplicada pelo `.githooks/pre-push`.

## Git, gates e release

1. **Branch por agente**: `<agente>/<slug>`. Nunca commit direto em `main` (o guard bloqueia).
2. **Cadência**: alterou, commitou — commits atômicos, mensagem com o quê, o porquê e o objetivo. Mudança indivisível em vários arquivos vai num commit só.
3. **Autoria** é sempre do dono; trailer `Co-Authored-By` do agente é permitido.
4. **Gates locais**: `git config core.hooksPath .githooks` em cada clone. Gate reprovou: corrija o código ou o gate (skill `gate-reprovou`). Exceção consciente: `HARNESS_SKIP=<gate>`, registrada no PENDING no ato.
5. **Merge só pelo `scripts/merge_gate.sh <PR>`**, que valida o RESULTADO do merge. Nunca o merge direto da plataforma; nunca `[skip ci]`.
6. **Release**: `<processo>`. Versão semântica conferida nos manifestos antes de qualquer push de versão.

## Documentação viva

- `CHANGELOG.md` e `ROADMAP.md` atualizados em cada repositório a cada entrega.
- **Toda entrega fecha nos dois registros centrais** (PENDING e CONCLUSION), de qualquer tamanho.
- Decisão estrutural: ADR **antes** de executar; GAP de Código não tem ADR; nunca ADR preventiva (skill `governanca-de-decisao`).
- Pressuposto de produto assumido por uma decisão é nomeado na ADR/CHANGELOG.

## Coexistência multi-agente

1. Antes de tarefa não trivial: `git status`/`git diff` nos repositórios alvo e leitura do quadro.
2. Nunca `git add -A`/`.`; confira `git diff --cached --stat` antes do commit.
3. Worktree se deriva de `origin/main`, nunca de `main` local.
4. `rm`/`mv`/`npm install` em worktree atravessam symlinks: `readlink -f` antes (skill `estado-compartilhado-multi-agente`).
5. Mergeou: apague branch local e remota com prova por dois métodos (skill `varredura-git-multi-repo`).
6. Ao terminar: quadro atualizado e handover.

## Skills do projeto

**Onde ficam**: skills se criam e se editam só em `.agents/skills/<nome>/SKILL.md`. `.claude/skills` é symlink para `../.agents/skills` (o Claude Code só descobre esse caminho); nunca o transforme em diretório real.

Transversais (carregar sempre): `vies-de-plausibilidade`, `disciplina-de-validacao`, `<skill de segurança do projeto>`.

| Skill | Quando ler |
|---|---|
| `<skill-de-dominio>` | `<gatilho concreto>` |

Toda lição que custou uma sessão vira skill (julgamento) ou gate (mecanismo) — skill `prosa-vira-gate`.
