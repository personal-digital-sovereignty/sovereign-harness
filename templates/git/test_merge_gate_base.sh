#!/usr/bin/env bash
# Teste hermético do vínculo merge↔base do merge_gate.sh (P1 do perfil legado).
#
# Uso: bash templates/git/test_merge_gate_base.sh templates/git/merge_gate.sh
#
# Repos git reais descartáveis + dublês de `gh` e de `git ls-remote` via PATH.
# Sem rede, sem flake: a "corrida na janela" é encenada pelo próprio dublê de
# `gh pr merge` (publica um rival antes de mergear), determinística sempre.
#
# Cenários: T1 base estável (verde) · T2 base moveu (recusa) · T3 head moveu
# (recusa) · T4 rival entra na janela do merge (recusa pós-merge, alto) ·
# T5 merge limpo de verdade (verde + vínculo confirmado).
set -uo pipefail

[ $# -eq 1 ] || { echo "uso: $0 <merge_gate.sh>" >&2; exit 1; }
GATE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[ -f "$GATE" ] || { echo "gate inexistente: $1" >&2; exit 1; }
KIT="$(cd "$(dirname "$GATE")/../.." && pwd)"
[ -f "$KIT/core/github_checks.py" ] || { echo "teste: KIT sem core/github_checks.py para GATE=$1" >&2; exit 1; }
REAL_GIT="$(command -v git)"
command -v jq >/dev/null || { echo "jq ausente" >&2; exit 1; }

PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }
ruim() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

conf() { git -C "$1" config user.email t@t >/dev/null && git -C "$1" config user.name t >/dev/null; }

# Monta origin + work + helper + dublês em $D; imprime o dir. Variáveis de
# cenário (FAKE_LSREMOTE, head_moved, rival) o chamador ajusta depois.
montar() {
    local D; D=$(mktemp -d)
    git init --bare -q "$D/origin.git"
    git clone -q "$D/origin.git" "$D/seed" 2>/dev/null
    conf "$D/seed"
    # Hooks versionados no repo (como em uso real): o gate os executa dentro do
    # worktree temporário, que só tem o que está commitado.
    mkdir -p "$D/seed/.githooks" "$D/seed/.harness"
    printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$D/seed/.githooks/pre-push"
    chmod +x "$D/seed/.githooks/pre-push"
    cp "$KIT/core/github_checks.py" "$D/seed/.harness/github_checks.py"
    echo base > "$D/seed/f.txt"
    git -C "$D/seed" add f.txt .githooks/pre-push .harness/github_checks.py
    git -C "$D/seed" commit -qm base
    git -C "$D/seed" push -q origin HEAD:main
    git -C "$D/origin.git" symbolic-ref HEAD refs/heads/main
    git -C "$D/seed" checkout -qb pr-1
    echo head > "$D/seed/f.txt"
    git -C "$D/seed" commit -qam head
    git -C "$D/seed" push -q origin pr-1
    git clone -q "$D/origin.git" "$D/work" 2>/dev/null; conf "$D/work"
    git clone -q "$D/origin.git" "$D/helper" 2>/dev/null; conf "$D/helper"
    git -C "$D/work" rev-parse origin/pr-1 > "$D/HEAD1"
    git -C "$D/work" rev-parse origin/main > "$D/BASE"
    mkdir -p "$D/bin"
    sed "s#__REAL_GIT__#$REAL_GIT#" > "$D/bin/git" <<'SHIM'
#!/usr/bin/env bash
if [ "${1:-}" = "ls-remote" ] && [ -n "${FAKE_LSREMOTE:-}" ]; then printf '%s\n' "$FAKE_LSREMOTE"; exit 0; fi
exec "__REAL_GIT__" "$@"
SHIM
    chmod +x "$D/bin/git"
    cat > "$D/bin/gh" <<'STUB'
#!/usr/bin/env bash
S="${TEST_STATE:?}"
n=$(cat "$S/calls" 2>/dev/null || echo 0); echo $((n+1)) > "$S/calls"
case "$1 $2" in
  "repo view") printf 'teste/kit' ;;
  "pr view")
    if [[ "$*" == *--jq* ]]; then
      if [ "$(cat "$S/calls")" -ge 2 ] && [ -f "$S/head_moved" ]; then cat "$S/HEAD2"; else cat "$S/HEAD1"; fi
    else
      printf '{"state":"OPEN","headRefName":"pr-1","headRefOid":"%s","baseRefName":"main","isDraft":false,"title":"t"}' "$(cat "$S/HEAD1")"
    fi ;;
  "pr checks") printf '[{"name":"ci","bucket":"pass"}]' ;;
  "pr merge")
    git -C "$S/helper" fetch -q origin
    git -C "$S/helper" checkout -q -B main origin/main
    if [ -f "$S/rival" ]; then
      echo rival > "$S/helper/rival.txt"; git -C "$S/helper" add rival.txt
      git -C "$S/helper" commit -qm rival; git -C "$S/helper" push -q origin main
      git -C "$S/helper" fetch -q origin; git -C "$S/helper" checkout -q -B main origin/main
    fi
    git -C "$S/helper" merge -q --squash "$(cat "$S/HEAD1")"
    git -C "$S/helper" commit -qm "squash pr-1"; git -C "$S/helper" push -q origin main
    printf 'Merged' ;;
  *) echo "gh dublê: comando inesperado: $*" >&2; exit 9 ;;
esac
STUB
    chmod +x "$D/bin/gh"
    [ -d "$D/work/.git" ] || return 1
    printf '%s' "$D"
}

# roda <dir> [args...]: executa o gate no work com PATH dos dublês; imprime saída.
# Herda FAKE_LSREMOTE do ambiente quando o cenário precisa (T2).
roda() {
    local D="$1"; shift
    (export TEST_STATE="$D" PATH="$D/bin:$PATH"; cd "$D/work" && bash "$GATE" "$@")
}

# --- T1: tudo estável -------------------------------------------------------
D=$(montar)
OUT=$(roda "$D" 1 --dry-run 2>&1); RC=$?
[ $RC -eq 0 ] && echo "$OUT" | grep -q "Todos os gates passaram" && ok "T1 base estável entra verde" || ruim "T1 rc=$RC :: $(echo "$OUT" | tail -2)"
rm -rf "$D"

# --- T2: base moveu ----------------------------------------------------------
D=$(montar)
echo x > "$D/seed/f.txt"; git -C "$D/seed" commit -qam rival-nao-publicado
RIVAL=$(git -C "$D/seed" rev-parse HEAD)
OUT=$(FAKE_LSREMOTE="$RIVAL refs/heads/main" roda "$D" 1 --dry-run 2>&1); RC=$?
[ $RC -eq 1 ] && echo "$OUT" | grep -q "origin/main mudou" && ok "T2 base movida recusa" || ruim "T2 rc=$RC :: $(echo "$OUT" | tail -2)"
rm -rf "$D"

# --- T3: head moveu ----------------------------------------------------------
D=$(montar)
git -C "$D/seed" checkout -q pr-1; echo x >> "$D/seed/f.txt"; git -C "$D/seed" commit -qam head2
git -C "$D/seed" rev-parse HEAD > "$D/HEAD2"; touch "$D/head_moved"
OUT=$(roda "$D" 1 --dry-run 2>&1); RC=$?
[ $RC -eq 1 ] && echo "$OUT" | grep -q "head do PR mudou" && ok "T3 head movido recusa" || ruim "T3 rc=$RC :: $(echo "$OUT" | tail -2)"
rm -rf "$D"

# --- T4: rival entra na janela do merge --------------------------------------
D=$(montar)
touch "$D/rival"
OUT=$(roda "$D" 1 2>&1); RC=$?
[ $RC -eq 1 ] && echo "$OUT" | grep -q "OUTRA base" && ok "T4 corrida na janela detectada alto" || ruim "T4 rc=$RC :: $(echo "$OUT" | tail -2)"
rm -rf "$D"

# --- T5: merge limpo de verdade ----------------------------------------------
D=$(montar)
OUT=$(roda "$D" 1 2>&1); RC=$?
[ $RC -eq 0 ] && echo "$OUT" | grep -q "vinculado à base validada" && ok "T5 merge limpo confirma vínculo" || ruim "T5 rc=$RC :: $(echo "$OUT" | tail -2)"
rm -rf "$D"

echo "merge_gate_base: $PASS passou, $FAIL falhou"
[ $FAIL -eq 0 ]
