# Sovereign Harness — kit de engenharia assistida por IA

Método e ferramentas para desenvolver software com vários agentes de IA (Claude Code, Codex, OpenCode, Antigravity) e um dono humano na mesma base de código. Extraído do processo real do projeto Sovereign Pair: cada regra tem um incidente de origem.

**A ideia:** o agente faz; mecanismos determinísticos fora dele conferem; o dono decide o que muda o mundo. O que é verificável vira gate; a prosa fica para o julgamento.

## O que vem no kit

**Desenvolvimento após 0.1.0:** avaliação crítica em
[docs/audits/release-0.1.0.md](docs/audits/release-0.1.0.md), direção em
[docs/ROADMAP.md](docs/ROADMAP.md). Os templates agora usam `docs/`, com PENDING,
ROADMAP e CONCLUSION separados, categorias de engenharia e skills para
classificação/fechamento. `core/documentation.py` migra por mapa explícito e
verifica destinos de links locais. Não valida âncoras, links web ou referências
em prosa; consumidores externos exigem revisão própria.

**Instalação padrão:** gates declarativos por projeto, sem inferir stack, forge,
branch ou membros. Preencha o contrato de validação antes do primeiro push.
O perfil legado GitHub/Rust/Node é opt-in com `--git-profile github-rust-node`.
Ver [configuração e limites](docs/CONFIGURATION.md). Instalação não certifica
uma stack, SO ou integração de agente não exercitados.

| Peça | Onde | Para quê |
|---|---|---|
| Guard do agente | `core/harness_guard.py` | bloqueia antes de executar 17 classes de ação perigosa (git add amplo, `--no-verify`, hooks desligados, stash compartilhado, `rm` através de symlink, commit em branch protegida, merge sem gate, `.env` no stdout, descarte de trabalho…). Escape nominal por regra. Só stdlib, Python ≥ 3.11 |
| Skills de método (15) | `skills/` | método, validação, segurança, governança documental, classificação e encerramento rastreável |
| Comandos (6) | `commands/` | `quadro`, `validar`, `fechamento`, `adr`, `gap`, `doc` |
| Claude Code | `.claude-plugin/marketplace.json`, `plugins/claude-code/` | plugin `sovereign-harness-guard` (hooks + comandos); `sovereign-harness-metodo` (skills) é opcional — as skills chegam pelo symlink `.claude/skills` |
| Codex | `.agents/plugins/marketplace.json`, `plugins/codex/` | plugin de skills; guard via `.codex/hooks.json` do projeto |
| OpenCode | `plugins/opencode/` | plugin TS em `tool.execute.before` |
| Antigravity | `plugins/antigravity/` | regras `always_on` e workflows |
| Gates de git | `core/validation.py`, `templates/git/` | comandos por argv/cwd; pre-push verifica checkout e refs; pre-commit verifica links. Adaptador GitHub/Rust/Node opcional |
| Documentação | `templates/docs/` | AGENTS.md, PENDING, ROADMAP, CONCLUSION, categorias e templates; migração explícita e verificador |
| Instalador | `install.sh` | idempotente, nunca sobrescreve |

## Convenção: tudo de agente em `.agents/`

| O quê | Onde | Compatibilidade |
|---|---|---|
| Instruções | `AGENTS.md` | `CLAUDE.md`, `GEMINI.md` → symlink |
| Skills | `.agents/skills/<nome>/SKILL.md` — único lugar de escrita | `.claude/skills → ../.agents/skills` (o Claude Code só descobre esse caminho e segue o symlink); OpenCode e Codex leem `.agents/skills` nativamente |
| Regras e workflows do Antigravity | `.agents/rules/`, `.agents/workflows/` | — |
| Quadro de trabalho, se adotado | `.agents/agents_work.md` | fonte e processo definidos pelo projeto; helper Git do perfil opcional |

O instalador cria o symlink do Claude e reporta como conflito um `.claude/skills` que seja diretório real.

## Instalar

**Plugins pelo marketplace (direto do GitHub):**

```bash
claude plugin marketplace add personal-digital-sovereignty/sovereign-harness
claude plugin install sovereign-harness-guard@sovereign-harness --scope project
codex plugin marketplace add personal-digital-sovereignty/sovereign-harness
```

**Método completo num projeto** (guard, gates de git, docs, skills em `.agents/skills`, adaptadores dos quatro agentes):

```bash
git clone https://github.com/personal-digital-sovereignty/sovereign-harness
```

```bash
./install.sh /caminho/do/projeto --verificar
./install.sh /caminho/do/projeto
```

Opções: `--agentes claude,codex,opencode,antigravity`, `--perfil <toml>`, `--git-profile portable|github-rust-node`, `--sem-skills`, `--skills-existentes <dir>`, `--sem-git`, `--sem-docs`, `--docs-dir <dir>` (padrão `docs`), `--project-name <nome>`, `--raiz-canonica <dir>`. Depois, no projeto alvo: preencher `AGENTS.md` e `.harness.toml`, executar `python3 .harness/validation.py check`, ativar `git config core.hooksPath .githooks`, instalar os plugins indicados no relatório e rodar os canários.

Python ≥ 3.11, Git e Bash são requisitos do instalador/hooks. A bateria roda
em Linux e macOS por PR (matriz no CI); Windows nativo precisa de validação
própria. Casos de uso reais por stack em [docs/examples/](docs/examples/README.md).
Confira o [índice documental](docs/README.md). O guard é heurístico e pode ter
falsos positivos/negativos: não é sandbox nem fronteira de segurança.

| Agente | Estado da integração |
|---|---|
| Claude Code | manifestos validados (`claude plugin validate`) |
| Codex | canário real verde; hooks de projeto exigem revisão de confiança no Codex |
| OpenCode | canário real verde nos dois sentidos |
| Antigravity | sem bloqueio de ação: só instrução; o bloqueio real fica nos gates de git |

## Desenvolver o kit

```bash
python3 scripts/sincronizar.py              # copia core/skills/commands para os plugins
python3 -m unittest discover -s core/tests  # guard + integridade do kit
```

As cópias em `plugins/` nunca se editam à mão; `sincronizar.py --verificar` falha se divergirem.

## Idioma

Documentação, skills e mensagens em **pt-BR** nesta versão. IDs de regra, chaves JSON e nomes de arquivo são contratos estáveis e não se traduzem. **en-US: pendente**, registrado no `ROADMAP.md` — até lá, o kit não anuncia suporte a outro idioma.

## Licença

[MIT](LICENSE) para todo o conteúdo. Nenhum código de terceiros é copiado para cá — ver [`NOTICE.md`](NOTICE.md). Histórico em [`CHANGELOG.md`](CHANGELOG.md).

## Origem

Extraído do processo de desenvolvimento do projeto Sovereign Pair, em que um dono e vários agentes de IA (Claude Code, Codex, OpenCode, Antigravity) trabalham na mesma árvore. Cada regra do guard e cada skill nasceu de um incidente real, com data — a origem está citada no próprio código e no texto.
