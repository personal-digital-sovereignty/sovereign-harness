#!/usr/bin/env bash
# =============================================================================
# Teste hermético da proteção da `main` do repositório de coordenação, contra um
# repositório DESCARTÁVEL com cópia dos hooks reais:
#   - pre-commit: commit direto na main só para o quadro (gate `main`);
#   - reference-transaction: a main só avança, e a árvore nova passa nos gates
#     de skills e de links, inclusive por merge e update-ref (que não passam
#     pelo pre-commit).
#
# Uso:  .agents/test_ref_main.sh [dir-dos-hooks] [documentation.py]
#       (padrão: .githooks e .harness/documentation.py do projeto; no kit:
#        templates/git e core/documentation.py)
#
# O verificador de skills é do projeto (o kit não o fornece): aqui um stub
# mínimo `check_skills.py --rev` prova o contrato que a guarda usa. Os links são
# verificados pelo documentation.py real do kit, nos dois caminhos que a guarda
# aceita (check_doc_refs.py do projeto e o fallback .harness/documentation.py).
# Cada regra é provada nos dois sentidos, e cada recusa exige a mensagem do
# gate certo: um cenário que "falha" pelo motivo errado não prova nada.
# =============================================================================
set -uo pipefail

AQUI=$(cd "$(dirname "$0")" && pwd)
HOOKS=$(realpath "${1:-$AQUI/../.githooks}") || exit 2
DOC=$(realpath "${2:-$AQUI/../.harness/documentation.py}") || exit 2
for f in "$HOOKS/pre-commit" "$HOOKS/reference-transaction" "$DOC"; do
    [ -f "$f" ] || { echo "falta $f"; exit 2; }
done
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT

export GIT_AUTHOR_NAME=teste GIT_AUTHOR_EMAIL=teste@exemplo.invalid
export GIT_COMMITTER_NAME=teste GIT_COMMITTER_EMAIL=teste@exemplo.invalid
unset HARNESS_SKIP GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

R="$T/meta"
case "$R" in "$T"/*) ;; *) echo "repo de teste fora do diretório temporário — abortando"; exit 2 ;; esac
falhas=0
ok()  { echo "✅ $1"; }
nok() { echo "❌ $1"; falhas=$((falhas + 1)); }
main_sha() { git -C "$R" rev-parse main; }
# prepara <descrição> -- comando...   (preparo que falha em silêncio faz o cenário testar nada)
prepara() {
    local desc=$1; shift 2
    local out; if ! out=$("$@" 2>&1); then nok "PREPARO falhou: $desc"; printf '%s\n' "$out" | tail -12 | sed 's/^/      /'; return 1; fi
}
# tenta <0|1> <trecho esperado na saída, ou vazio> <descrição> -- comando...
# Here-string, nunca `printf | grep -q`: sob pipefail o grep -q sai cedo e o
# produtor leva SIGPIPE — o pipeline "falha" e a asserção mente.
tenta() {
    local quer=$1 trecho=$2 desc=$3; shift 4
    local out rc; out=$("$@" 2>&1); rc=$?
    [ "$rc" -ne 0 ] && rc=1
    if [ "$rc" -eq "$quer" ] && { [ -z "$trecho" ] || grep -qF -- "$trecho" <<<"$out"; }; then ok "$desc"
    else nok "$desc (exit=$rc, esperado=$quer, trecho='$trecho')"; printf '%s\n' "$out" | tail -8 | sed 's/^/      /'; fi
}
skill_ok()   { mkdir -p "$R/.agents/skills/$1"; printf -- '---\nname: %s\ndescription: Carregar quando testar.\n---\n\n## 1. Um\n\ntexto\n' "$1" > "$R/.agents/skills/$1/SKILL.md"; }
skill_ruim() { mkdir -p "$R/.agents/skills/$1"; printf '# Skill: %s\n\n## 1. Um\n' "$1" > "$R/.agents/skills/$1/SKILL.md"; }

git init -q -b main "$R" && cd "$R" || exit 1
mkdir -p .githooks .harness .agents docs
cp "$HOOKS/pre-commit" "$HOOKS/reference-transaction" .githooks/
cp "$DOC" .harness/documentation.py
# Stub do verificador de skills do projeto: SKILL.md alterado precisa abrir com frontmatter.
cat > .githooks/check_skills.py <<'PY'
import subprocess, sys
a = sys.argv[1:]
novo = a[a.index("--rev") + 1]
base = a[a.index("--base-rev") + 1] if "--base-rev" in a else None
cmd = ["git", "diff", "--name-only", "--diff-filter=AMR", base, novo] if base else ["git", "ls-tree", "-r", "--name-only", novo]
ruins = [c for c in subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.split()
         if c.endswith("SKILL.md")
         and not subprocess.run(["git", "show", f"{novo}:{c}"], capture_output=True, text=True).stdout.startswith("---\nname:")]
for c in ruins:
    print(f"{c}: sem frontmatter")
sys.exit(1 if ruins else 0)
PY
# Verificador de links do projeto: aqui, o documentation.py real do kit.
cat > .githooks/check_doc_refs.py <<PY
import subprocess, sys
a = sys.argv[1:]
raiz = a[a.index("--root") + 1] if "--root" in a else "."
sys.exit(subprocess.call([sys.executable, "$R/.harness/documentation.py", "--root", raiz, "check", "docs"]))
PY
printf '.githooks/\n.harness/\n' >> .git/info/exclude
printf '# Quadro\n\n## Em andamento\n' > .agents/agents_work.md
printf '# Docs\n' > docs/README.md
skill_ok base
git add -A && git commit -qm base            # hooks ainda desligados: a base é o ponto de partida
git config core.hooksPath "$R/.githooks"     # config LOCAL do repo descartável

# --- B: commit direto na main ----------------------------------------------------
echo x >> docs/README.md && git add docs/README.md
tenta 1 "commit direto na main do repositório de coordenação" "B1 commit direto na main de arquivo comum é recusado pelo gate main" -- git commit -qm "direto na main"
git reset -q --hard

echo "entrada" >> .agents/agents_work.md && git add .agents/agents_work.md
tenta 0 "" "B2 commit do quadro sozinho na main passa" -- git commit -qm "quadro"

echo y >> docs/README.md && git add docs/README.md
tenta 0 "commit direto na main permitido (HARNESS_SKIP)" "B3 HARNESS_SKIP=main deixa passar e diz que pulou" -- env HARNESS_SKIP=main git commit -qm "exceção"

git checkout -q -b claude/trabalho
echo z >> docs/README.md
tenta 0 "" "B4 commit numa branch de agente passa" -- git commit -qam "na branch"

# --- A: a main só avança, e por merge a árvore nova passa nos gates --------------
git checkout -q main
antes=$(main_sha)
tenta 0 "" "A1 merge fast-forward de conteúdo válido avança a main" -- git merge -q --ff-only claude/trabalho
[ "$(main_sha)" != "$antes" ] || nok "A1 a main não andou"

prepara "branch claude/skill-quebrada" -- git checkout -q -b claude/skill-quebrada
skill_ruim base && git add -A
prepara "commit da skill sem frontmatter na branch" -- git commit -qm "skill sem frontmatter"
prepara "voltar à main" -- git checkout -q main; antes=$(main_sha)
tenta 1 "Gate skills reprovou a árvore nova" "A2a a guarda recusa citando o gate skills" -- git merge -q --ff-only claude/skill-quebrada
[ "$(main_sha)" = "$antes" ] && ok "A2 merge FF de skill sem frontmatter é recusado (pre-commit não roda em merge)" || { nok "A2 skill quebrada entrou na main por merge"; git reset -q --hard "$antes"; }
# Efeito colateral medido: o merge recusado já escreveu o conteúdo na árvore de trabalho.
# A guarda lista os arquivos e manda restaurar só eles (nunca reset --hard no checkout principal).
saida=$(git merge -q --ff-only claude/skill-quebrada 2>&1)
grep -qF "git restore --source=main --staged --worktree" <<<"$saida" && grep -qF ".agents/skills/base/SKILL.md" <<<"$saida" && ok "A2b a recusa lista os arquivos e o restore seletivo" || nok "A2b a recusa não ensinou a restaurar: $saida"
git restore --source=main --staged --worktree -- .agents/skills/base/SKILL.md
[ -z "$(git status --porcelain -- .agents/skills/base/SKILL.md)" ] && ok "A2c o restore sugerido limpa a árvore de trabalho" || nok "A2c o restore sugerido não limpou"
tenta 1 "Gate skills reprovou a árvore nova" "A3a merge --no-ff recusado pela guarda (gate skills)" -- git merge -q --no-ff -m "merge" claude/skill-quebrada
[ "$(main_sha)" = "$antes" ] && ok "A3 merge --no-ff da mesma skill é recusado" || { nok "A3 merge commit levou a skill quebrada"; git reset -q --hard "$antes"; }
git merge --abort >/dev/null 2>&1
git restore --source=main --staged --worktree -- .agents/skills/base/SKILL.md
[ -z "$(git status --porcelain)" ] || nok "PREPARO: árvore suja antes do A4: $(git status --porcelain | tr '\n' ' ')"
tenta 1 "Gate skills reprovou a árvore nova" "A4a update-ref recusado pela guarda (gate skills)" -- git update-ref refs/heads/main claude/skill-quebrada "$antes"
[ "$(main_sha)" = "$antes" ] && ok "A4 update-ref (CAS) para a skill quebrada é recusado" || { nok "A4 update-ref levou a skill quebrada"; git update-ref refs/heads/main "$antes"; }

[ -z "$(git status --porcelain)" ] || nok "PREPARO: árvore suja antes do A5: $(git status --porcelain | tr '\n' ' ')"
prepara "branch claude/link-quebrado" -- git checkout -q -b claude/link-quebrado main
printf '# Docs\n\n[x](nao-existe.md)\n' > docs/README.md
prepara "commit do link quebrado na branch" -- env HARNESS_SKIP=docrefs git commit -qam "link quebrado"
prepara "voltar à main" -- git checkout -q main
tenta 1 "Gate docrefs reprovou a árvore nova" "A5a a guarda recusa citando o gate docrefs (check_doc_refs.py do projeto)" -- git update-ref refs/heads/main claude/link-quebrado "$antes"
[ "$(main_sha)" = "$antes" ] && ok "A5 link quebrado é recusado (docrefs na árvore nova)" || { nok "A5 link quebrado entrou"; git update-ref refs/heads/main "$antes"; }
mv .githooks/check_doc_refs.py "$T/check_doc_refs.py"
tenta 1 "Gate docrefs reprovou a árvore nova" "A5b sem check_doc_refs.py, o fallback .harness/documentation.py recusa" -- git update-ref refs/heads/main claude/link-quebrado "$antes"
[ "$(main_sha)" = "$antes" ] || { nok "A5b link quebrado entrou pelo fallback"; git update-ref refs/heads/main "$antes"; }
tenta 0 "docrefs pulado (HARNESS_SKIP)" "A5c HARNESS_SKIP=docrefs pula só os links e diz que pulou" -- env HARNESS_SKIP=docrefs git update-ref refs/heads/main claude/link-quebrado "$antes"
mv "$T/check_doc_refs.py" .githooks/check_doc_refs.py
HARNESS_SKIP=main-ref git update-ref refs/heads/main "$antes"
git restore --source=main --staged --worktree -- . >/dev/null 2>&1

[ -z "$(git status --porcelain)" ] || nok "PREPARO: árvore suja antes do A6: $(git status --porcelain | tr '\n' ' ')"
prepara "branch claude/skill-boa" -- git checkout -q -b claude/skill-boa main
skill_ok nova && git add -A
prepara "commit da skill nova válida" -- git commit -qm "skill nova válida"
prepara "voltar à main" -- git checkout -q main
tenta 0 "" "A6 merge de skill nova válida avança a main" -- git merge -q --ff-only claude/skill-boa

antes=$(main_sha)
tenta 1 "NÃO descende dela" "A7a a guarda recusa recuo explicando o motivo" -- git reset -q --hard HEAD~1
[ "$(main_sha)" = "$antes" ] && ok "A7 reset --hard para trás na main é recusado" || { nok "A7 main andou para trás"; HARNESS_SKIP=main-ref git reset -q --hard "$antes"; }
git reset -q --hard "$antes"
tenta 1 "APAGARIA a branch" "A8a a guarda recusa apagar a main" -- git update-ref -d refs/heads/main
git rev-parse -q --verify refs/heads/main >/dev/null && ok "A8 apagar a main é recusado" || { nok "A8 main apagada"; git update-ref refs/heads/main "$antes"; }

tenta 0 "guarda da main pulada (HARNESS_SKIP)" "A9 HARNESS_SKIP=main-ref deixa recuar e diz que pulou" -- env HARNESS_SKIP=main-ref git reset -q --hard HEAD~1
[ "$(main_sha)" != "$antes" ] || nok "A9 a main não recuou com a exceção"
HARNESS_SKIP=main-ref git reset -q --hard "$antes"

git checkout -q claude/trabalho
b=$(git rev-parse HEAD)
tenta 0 "" "A10 refs que não são a main não são afetadas (reset numa branch)" -- git reset -q --hard HEAD~1
[ "$(git rev-parse HEAD)" != "$b" ] || nok "A10 a branch não recuou"

# --- Q: conclusão de merge com conflito que só traz o quadro da main --------------
prepara "voltar à main para Q" -- git checkout -q main
prepara "branch claude/conflito" -- git checkout -q -b claude/conflito main
printf '# Docs\nversao-branch\n' > docs/README.md
prepara "commit na branch" -- git commit -qam "branch mexe no README"
prepara "volta à main" -- git checkout -q main
printf '# Docs\nversao-main\n' > docs/README.md
echo "entrada-nova" >> .agents/agents_work.md
prepara "main mexe no README e no quadro" -- env HARNESS_SKIP=main,quadro git commit -qam "main mexe"
prepara "volta à branch" -- git checkout -q claude/conflito
git merge -q main >/dev/null 2>&1
printf '# Docs\nresolvido\n' > docs/README.md && git add docs/README.md
tenta 0 "" "Q1 concluir merge que só traz o quadro da main passa sem exceção" -- git commit -q --no-edit
prepara "nova divergência" -- git commit -q --allow-empty -m vazio
prepara "volta à main" -- git checkout -q main
printf '# Docs\nmain-2\n' > docs/README.md
prepara "main mexe de novo" -- env HARNESS_SKIP=main git commit -qam "main 2"
prepara "volta à branch" -- git checkout -q claude/conflito
git merge -q main >/dev/null 2>&1
printf '# Docs\nresolvido-2\n' > docs/README.md && git add docs/README.md
echo "edicao-minha" >> .agents/agents_work.md && git add .agents/agents_work.md
tenta 1 "COMMIT BLOQUEADO — .agents/agents_work.md" "Q2 merge que EDITA o quadro fora da main continua barrado" -- git commit -q --no-edit

# --- P: `produtor | grep -q` sob pipefail (o grep sai cedo, o produtor leva SIGPIPE,
# o pipeline "falha"). Medido em 2026-10-23: `env | grep -q` errou 152/300 e fazia
# HARNESS_SKIP=docrefs ser ignorado ao acaso; `printf grande | grep -q`, 200/200.
git merge --abort >/dev/null 2>&1; git checkout -q -f main >/dev/null 2>&1
prepara "branch claude/skip-docrefs" -- git checkout -q -b claude/skip-docrefs main
ok_skip=0
for i in $(seq 1 30); do
    printf '# Docs\n\n[x](nao-existe-%s.md)\n' "$i" > docs/README.md
    HARNESS_SKIP=docrefs git commit -qam "skip $i" >/dev/null 2>&1 && ok_skip=$((ok_skip + 1))
done
[ "$ok_skip" -eq 30 ] && ok "P1 HARNESS_SKIP=docrefs reconhecido em 30/30 commits" || nok "P1 skip do docrefs ignorado em $((30 - ok_skip))/30 commits"
git checkout -q -f main
prepara "branch claude/merge-grande" -- git checkout -q -b claude/merge-grande main
mkdir -p massa && for i in $(seq 1 6000); do echo "$i" > "massa/f$i.txt"; done
skill_ruim base
git add -A >/dev/null
prepara "commit grande com skill quebrada" -- git commit -qm "6000 arquivos + skill quebrada"
prepara "volta à main" -- git checkout -q main
antes=$(main_sha)
tenta 1 "Gate skills reprovou a árvore nova" "P2 update-ref de 6000 arquivos com skill quebrada é recusado (sem falsa negativa)" -- git update-ref refs/heads/main claude/merge-grande "$antes"

echo
[ "$falhas" -eq 0 ] && { echo "test_ref_main: tudo verde"; exit 0; }
echo "test_ref_main: $falhas falha(s)"; exit 1
