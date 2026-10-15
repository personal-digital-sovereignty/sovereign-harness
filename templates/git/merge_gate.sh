#!/usr/bin/env bash
# =============================================================================
# Sovereign Pair · merge gate — o ÚNICO ponto onde "merge só com a esteira verde"
# pode ser exigido nesta organização (E62 / ADR-041 item 9).
#
# Por quê local: a org é GitHub Free com repositórios privados — branch protection,
# rulesets e environments com aprovação respondem `403 Upgrade to GitHub Pro`
# (medido em 2026-09-13). O GitHub não tem como recusar um merge vermelho aqui.
#
# O que faz, nesta ordem:
#   1. monta o RESULTADO do merge (origin/main + a branch do PR) num worktree
#      temporário — valida o que a main vai virar, não só a branch;
#   2. roda ali o PRÓPRIO `.githooks/pre-push` do repo (gitleaks, trivy, semgrep,
#      types, test, lint) — uma fonte de verdade só, nada duplicado;
#   3. roda o que o hook não cobre e a esteira remota cobre: actionlint, ruff+pytest
#      de `python_workers/`, e o build de produção (no Shell, o bundle federado);
#   4. consulta o sinal remoto (`gh pr checks`, o devsecops.yml no runner self-hosted):
#      check vermelho ou pendente RECUSA; PR sem check nenhum avisa e segue (o runner
#      pode estar desligado — o gate local decide sozinho);
#   5. só então chama `gh pr merge`.
#
# Uso:
#   scripts/merge_gate.sh <numero-do-PR> [--dry-run] [-- <args extras do gh pr merge>]
#   padrão do merge: --squash --delete-branch
#
# Exceção consciente, nomeada, igual ao pre-push:
#   HARNESS_SKIP=trivy,build scripts/merge_gate.sh 42
#   gates daqui: actionlint, python, build, remote   (mais os 6 do pre-push)
#
# Mantenha este arquivo IDÊNTICO em todos os repositórios do projeto (confira com md5sum ao alterar).
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
die() { echo -e "${RED}❌ merge gate: $*${NC}" >&2; exit 1; }

PR=''; DRY=0; EXTRA=()
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --) shift; EXTRA=("$@"); break ;;
        -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) if [ -z "$PR" ]; then PR="$1"; else die "argumento inesperado: $1"; fi ;;
    esac
    shift
done
[[ "$PR" =~ ^[0-9]+$ ]] || die "uso: scripts/merge_gate.sh <numero-do-PR> [--dry-run] [-- args do gh pr merge]"

SKIP="${HARNESS_SKIP:-}"
skipped() { case ",$SKIP," in *",all,"*|*",$1,"*) return 0 ;; esac; return 1; }
precisa_de() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}   ferramenta ausente: $1 — $2${NC}"; return 127; }; }

# Mesma higiene do pre-push: nada de GIT_DIR herdado atravessando os filhos.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
REPO_ROOT=$(git rev-parse --show-toplevel) || die "rode de dentro do repositório"
cd "$REPO_ROOT" || die "não consegui entrar em $REPO_ROOT"
REPO_NAME=$(basename "$REPO_ROOT")
precisa_de gh "https://cli.github.com" || exit 127
precisa_de jq "apt install jq / brew install jq" || exit 127
REPO_SLUG=$(gh repo view --json nameWithOwner --jq .nameWithOwner) || die "não consegui identificar o repositório remoto"
[ -x .githooks/pre-push ] || die ".githooks/pre-push ausente ou sem bit de execução — sem ele não há gate"

echo -e "\n${BLUE}━━━ Sovereign Pair · merge gate · ${REPO_NAME} · PR #${PR} ━━━${NC}"
[ -n "$SKIP" ] && echo -e "${YELLOW}⚠️  HARNESS_SKIP=${SKIP} — pulando gate(s) por decisão explícita${NC}"

INFO=$(gh pr view "$PR" --json state,headRefName,headRefOid,baseRefName,isDraft,title) || die "não consegui ler o PR #$PR"
STATE=$(jq -r .state <<<"$INFO"); HEAD_REF=$(jq -r .headRefName <<<"$INFO"); HEAD_SHA=$(jq -r .headRefOid <<<"$INFO")
BASE_REF=$(jq -r .baseRefName <<<"$INFO"); IS_DRAFT=$(jq -r .isDraft <<<"$INFO")
[ "$STATE" = OPEN ] || die "PR #$PR está $STATE"
[ "$IS_DRAFT" = false ] || die "PR #$PR é draft"
[ "$BASE_REF" = main ] || die "PR #$PR aponta para '$BASE_REF', não para main"
echo "   $(jq -r .title <<<"$INFO")"
echo "   $HEAD_REF @ ${HEAD_SHA:0:10}  →  main"

git fetch -q origin main "$HEAD_REF" || die "git fetch falhou (ssh-agent? ver skill diagnostico-ssh-agent-git)"
[ "$(git rev-parse "origin/$HEAD_REF")" = "$HEAD_SHA" ] || die "origin/$HEAD_REF não é o head do PR — alguém publicou no meio; rode de novo"
BASE_SHA=$(git rev-parse origin/main)

# Irmão do repo (não /tmp): builds que resolvem dependência por caminho
# relativo ao diretório-pai (ex.: `file:../<pacote-local>`) funcionam aqui.
WT="$(dirname "$REPO_ROOT")/harness-merge-gate.$$.${REPO_NAME}"
limpa() {
    [ -L "$WT/node_modules" ] && rm -f "$WT/node_modules"      # só o LINK, nunca o alvo
    git worktree remove --force "$WT" >/dev/null 2>&1
    git worktree prune >/dev/null 2>&1
}
trap limpa EXIT
git worktree add -q --detach "$WT" "$BASE_SHA" || die "não consegui criar o worktree temporário"
cd "$WT" || die "não consegui entrar no worktree temporário"
if ! git -c user.name="merge-gate" -c user.email="merge-gate@localhost" merge -q --no-ff --no-edit "$HEAD_SHA" >/dev/null 2>&1; then
    echo -e "${RED}❌ o merge de $HEAD_REF em main CONFLITA:${NC}"; git diff --name-only --diff-filter=U | sed 's/^/     /'
    exit 1
fi
MERGED_SHA=$(git rev-parse HEAD)   # commit temporário, só local: nunca é publicado
echo "   resultado do merge montado em worktree temporário (${MERGED_SHA:0:10})"

# Ambiente de build do repo principal, por link — nunca instalar nada aqui dentro.
[ -d "$REPO_ROOT/node_modules" ] && ln -s "$REPO_ROOT/node_modules" "$WT/node_modules"
[ -f Cargo.toml ] && export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$REPO_ROOT/target}"

FAILED=()
LOGDIR=$(mktemp -d)
run_gate() {
    local nome="$1"; shift
    if skipped "$nome"; then echo -e "${YELLOW}⏭  ${nome}: pulado (HARNESS_SKIP)${NC}"; return 0; fi
    local ini rc; ini=$(date +%s)
    "$@" >"$LOGDIR/$nome.log" 2>&1; rc=$?
    if [ $rc -eq 0 ]; then echo -e "${GREEN}✅ ${nome} ($(( $(date +%s) - ini ))s)${NC}"
    else
        echo -e "${RED}❌ ${nome} ($(( $(date +%s) - ini ))s) — saída completa: $LOGDIR/$nome.log${NC}"
        tail -n 15 "$LOGDIR/$nome.log" | sed 's/^/     /'
        FAILED+=("$nome")
    fi
}

# ── 1. os 6 gates do pre-push, sobre o resultado do merge ────────────────────────────
echo -e "${BLUE}── pre-push do repo, sobre o resultado do merge${NC}"
URL_SEM_CREDENCIAL=$(git remote get-url origin 2>/dev/null | sed -E 's#(https://)[^@/]+@#\1#')
if ! printf 'refs/heads/merge-gate %s refs/heads/main %s\n' "$MERGED_SHA" "$BASE_SHA" | .githooks/pre-push origin "$URL_SEM_CREDENCIAL"; then
    FAILED+=("pre-push")
fi

# ── 2. o que o hook não cobre e a esteira remota cobre ───────────────────────────────
echo -e "${BLUE}── gates que só a esteira remota tinha${NC}"
if [ -d .github/workflows ]; then
    gate_actionlint() { precisa_de actionlint "https://github.com/rhysd/actionlint (brew install actionlint)" || return 127; actionlint; }
    run_gate actionlint gate_actionlint
fi
if [ -d python_workers/tests ]; then
    gate_python() {
        precisa_de ruff "pipx install ruff" || return 127
        precisa_de pytest "pipx install pytest (com pandas e tabulate)" || return 127
        ruff check python_workers/ --select E,F --ignore E501,E701 && pytest python_workers/tests/ -q --tb=short
    }
    run_gate python gate_python
fi
if [ -f package.json ] && jq -e '.scripts.build' package.json >/dev/null 2>&1; then
    gate_build() { NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=4096}" npm run build --silent; }
    run_gate build gate_build
fi

# ── 3. sinal remoto: o devsecops.yml do PR no runner self-hosted ─────────────────────
if skipped remote; then
    echo -e "${YELLOW}⏭  remote: pulado (HARNESS_SKIP)${NC}"
else
    CHECKS=$(gh pr checks "$PR" --json name,bucket 2>/dev/null || echo '[]')
    N=$(jq 'length' <<<"$CHECKS"); RUINS=$(jq -r '[.[]|select(.bucket=="fail" or .bucket=="cancel")|.name]|join(", ")' <<<"$CHECKS")
    PEND=$(jq -r '[.[]|select(.bucket=="pending")|.name]|join(", ")' <<<"$CHECKS")
    if [ "$N" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  remote: o PR não tem NENHUM check (runner desligado? commit com [skip ci]?) — o gate local decide sozinho${NC}"
    elif [ -n "$RUINS" ]; then
        echo -e "${RED}❌ remote: check(s) vermelho(s) no runner: $RUINS${NC}"; FAILED+=("remote")
    elif [ -n "$PEND" ]; then
        echo -e "${RED}❌ remote: check(s) ainda rodando: $PEND — espere terminar${NC}"; FAILED+=("remote")
    else
        echo -e "${GREEN}✅ remote: $N check(s) verdes no head ${HEAD_SHA:0:10}${NC}"
    fi
fi

cd "$REPO_ROOT" || die "não consegui voltar para $REPO_ROOT"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "\n${RED}❌ MERGE RECUSADO — reprovou: ${FAILED[*]}${NC}"
    echo -e "${YELLOW}   Se um gate reprovou, ou o código está errado, ou o gate está errado — as duas coisas se"
    echo -e "   resolvem, não se contornam. Exceção consciente: HARNESS_SKIP=<gate> $0 $PR${NC}"
    exit 1
fi
echo -e "\n${GREEN}✅ Todos os gates passaram sobre o resultado do merge.${NC}"
if [ $DRY -eq 1 ]; then echo "   --dry-run: o merge NÃO foi feito."; exit 0; fi

[ ${#EXTRA[@]} -eq 0 ] && EXTRA=(--squash --delete-branch)
MERGE_CWD=$(mktemp -d) || die "não consegui criar diretório isolado para o merge remoto"
# Fora de um checkout, o gh não tenta trocar/atualizar a main local depois do merge.
if ! (cd "$MERGE_CWD" && gh pr merge "$PR" --repo "$REPO_SLUG" --match-head-commit "$HEAD_SHA" "${EXTRA[@]}"); then
    rmdir "$MERGE_CWD" 2>/dev/null || true
    die "gh pr merge falhou"
fi
rmdir "$MERGE_CWD" 2>/dev/null || echo -e "${YELLOW}⚠️  merge: diretório temporário preservado em $MERGE_CWD${NC}"
echo -e "${GREEN}✅ PR #$PR mergeado.${NC} Atualize a main local: git switch main && git pull --ff-only"
