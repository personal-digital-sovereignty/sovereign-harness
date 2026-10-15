# Instruções para agentes de IA — <nome do projeto>

> Fonte única das instruções do projeto. `CLAUDE.md` e `GEMINI.md` são symlinks para este arquivo;
> o Antigravity o recebe pela regra `always_on` em `.agents/rules/`; Codex e OpenCode o leem nativamente.
> Preencha os campos `<...>`. Mantenha curto: o que é verificável vira gate, o que é julgamento vira skill.

## Leitura obrigatória

- Organização: [docs/README.md](docs/README.md).
- Arquitetura: [docs/architecture/README.md](docs/architecture/README.md).
- Pendências: [docs/PENDING.md](docs/PENDING.md) — somente trabalho aberto.
- Direção e sequência: [docs/ROADMAP.md](docs/ROADMAP.md).
- Histórico: [docs/CONCLUSION.md](docs/CONCLUSION.md).
- Quadro de trabalho: `.agents/agents_work.md`; configurar fonte canônica quando houver várias sessões.

## Perfil do projeto

Declarar topologia (repo único, monorepo ou metarrepositório), membros e fronteiras
de responsabilidade, branch principal/remotes quando existirem, stack, comandos
reais de validação, idiomas/locales e autoridades de aprovação. O harness não
infere esses contratos a partir de nomes de pasta. Membros independentes mantêm
seus próprios hooks e histórico; o meta-repo não executa testes deles implicitamente.

## Comunicação

- Idioma: `<idioma>`. Técnico e direto, sem bajulação.
- Senso crítico: revise a própria sugestão contra o histórico do projeto antes de propor.

## Segurança e soberania

1. **Nenhum fallback silencioso.** Falhou: logue e estoure o erro (fail-loud).
2. **Credenciais** só por ambiente/cofre; nunca no código, em fixture, commit, PR ou log (skill `manuseio-segredos`).
3. **Dependência de sistema ausente**: reproduza o erro, identifique o pacote e siga as permissões e autorizações vigentes do projeto; nunca contorne o requisito silenciosamente.

## Testes e validação

1. Executar os testes necessários ao comportamento alterado e os gates obrigatórios do projeto. Validar integrações reais quando disponíveis; doubles não certificam um serviço ou ambiente real.
2. Escolher ferramenta E2E conforme a interface. Projeto sem interface não precisa de teste de navegador; registrar a razão.
3. Todo verificador novo é provado no sentido negativo (skill `disciplina-de-validacao`).
4. Bateria completa antes de qualquer push — aplicada pelo `.githooks/pre-push`.

## Git, gates e release

1. **Branch por trabalho** conforme política do projeto; configurar ramos protegidos no guard.
2. **Cadência**: alterou, commitou — commits atômicos, mensagem com o quê, o porquê e o objetivo. Mudança indivisível em vários arquivos vai num commit só.
3. **Autoria** segue a identidade Git configurada e a política de contribuição. Não alterar identidade global.
4. **Gates locais**: configurar comandos reais em `.harness.toml` antes de ativar `git config core.hooksPath .githooks` em cada clone. Gate reprovou: corrija o código ou o gate (skill `gate-reprovou`). O runner portátil não oferece bypass por variável; escapes do guard e do perfil legado são mecanismos distintos e não certificam validação.
5. **Merge** pelo mecanismo aprovado pelo projeto, com validação do resultado integrado. Adaptador GitHub só se aplica quando essa for a forge; repositório local não exige PR remoto. Não desativar os checks requeridos.
6. **Release**: `<processo>`. Versão semântica conferida nos manifestos antes de qualquer push de versão.

## Documentação viva

- `CHANGELOG.md` registra mudanças; `docs/ROADMAP.md` registra sequência. Respeitar arquivos já existentes e definir uma única fonte por escopo.
- **Toda entrega fecha nos dois registros centrais** (PENDING e CONCLUSION), de qualquer tamanho.
- Decisão estrutural: ADR **antes** de executar; GAP de Código não tem ADR; nunca ADR preventiva (skill `governanca-de-decisao`).
- Pressuposto de produto assumido por uma decisão é nomeado na ADR/CHANGELOG.
- Use `classificar-documentacao` ao criar/mover documentos e `encerrar-documentacao` no fechamento. Épicos e ADRs mantêm vínculos nos dois sentidos; IDs e decisões históricas permanecem estáveis.

## Coexistência multi-agente

1. Antes de tarefa não trivial: `git status`/`git diff` nos repositórios alvo e leitura do quadro, quando adotado pelo projeto.
2. Nunca `git add -A`/`.`; confira `git diff --cached --stat` antes do commit.
3. Worktree deriva da referência atualizada escolhida pelo projeto; conferir remote e branch. Sem remote, a referência local é a fonte.
4. `rm`/`mv`/`npm install` em worktree atravessam symlinks: `readlink -f` antes (skill `estado-compartilhado-multi-agente`).
5. Limpeza de branches segue a política e autorização do projeto, com prova de integração e preservação de trabalho exclusivo.
6. Ao terminar: quadro atualizado, se adotado, e handover.

## Skills do projeto

**Onde ficam**: skills se criam e se editam só em `.agents/skills/<nome>/SKILL.md`. `.claude/skills` é symlink para `../.agents/skills` (o Claude Code só descobre esse caminho); nunca o transforme em diretório real.

Transversais (carregar sempre): `vies-de-plausibilidade`, `disciplina-de-validacao`, `<skill de segurança do projeto>`.

| Skill | Quando ler |
|---|---|
| `<skill-de-dominio>` | `<gatilho concreto>` |

Toda lição que custou uma sessão vira skill (julgamento) ou gate (mecanismo) — skill `prosa-vira-gate`.
