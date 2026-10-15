#!/usr/bin/env bash
# =============================================================================
# Instala o harness Sovereign num projeto — guard, gates de git, docs e agentes.
# =============================================================================
# Uso:
#   ./install.sh <alvo> [opções]
#
# Opções:
#   --agentes claude,codex,opencode,antigravity   (padrão: os quatro)
#   --perfil <arquivo.toml>        config do projeto (padrão: core/harness.example.toml)
#   --sem-skills                   o projeto já tem as próprias skills em .agents/skills;
#                                  não instala as do kit (só garante os symlinks)
#   --skills-existentes <dir>      skills vivem em outro diretório: .agents/skills vira
#                                  symlink relativo para <dir> (prefira mover para .agents/skills)
#   --sem-git                      não instala pre-push/pre-commit/merge_gate/quadro.sh
#   --git-profile portable|github-rust-node  padrão: portable, gates declarados no TOML
#   --sem-docs                     não instala AGENTS.md, PENDING/CONCLUSION, ADR, quadro
#   --docs-dir <dir>               onde vivem os docs do projeto, relativo à raiz
#                                  (padrão: docs). O AGENTS.md instalado tem
#                                  suas refs reescritas para este diretório.
#   --project-name <nome>          preenche o título do AGENTS.md instalado; sem a
#                                  flag, o placeholder <nome do projeto> fica para
#                                  quem instala preencher.
#   --verificar                    não escreve nada; lista o que faltaria/conflitaria
#   --raiz-canonica <dir>          caminho absoluto usado nos arquivos que gravam caminho
#                                  (o .codex/hooks.json). Padrão: o próprio alvo. Use quando
#                                  gerar a instalação num worktree que vai ser mergeado.
#
# Garantias:
#   - NUNCA sobrescreve. Arquivo existente e diferente vira CONFLITO listado no fim.
#   - Idempotente: rodar de novo sobre a mesma versão não muda nada.
#   - Não ativa `core.hooksPath` nem instala plugin no seu usuário: imprime os
#     comandos. Mudança de config é decisão de quem instala.
# =============================================================================
set -uo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
AGENTES="claude,codex,opencode,antigravity"
PERFIL="$KIT/core/harness.example.toml"
SKILLS_EXISTENTES=""
PROJECT_NAME=""
DOCS_DIR="docs"
SEM_SKILLS=0
RAIZ_CANONICA=""
COM_GIT=1; COM_DOCS=1; VERIFICAR=0
GIT_PROFILE="portable"
ALVO=""

while [ $# -gt 0 ]; do
    case "$1" in
        --agentes) AGENTES="$2"; shift ;;
        --perfil) PERFIL="$2"; shift ;;
        --skills-existentes) SKILLS_EXISTENTES="$2"; shift ;;
        --project-name) PROJECT_NAME="$2"; shift ;;
        --docs-dir) DOCS_DIR="$2"; shift ;;
        --sem-skills) SEM_SKILLS=1 ;;
        --raiz-canonica) RAIZ_CANONICA="$2"; shift ;;
        --sem-git) COM_GIT=0 ;;
        --git-profile) GIT_PROFILE="$2"; shift ;;
        --sem-docs) COM_DOCS=0 ;;
        --verificar) VERIFICAR=1 ;;
        -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "opção desconhecida: $1" >&2; exit 1 ;;
        *) [ -z "$ALVO" ] && ALVO="$1" || { echo "argumento inesperado: $1" >&2; exit 1; } ;;
    esac
    shift
done
[ -n "$ALVO" ] || { echo "uso: $0 <alvo> [opções] (--help)" >&2; exit 1; }
[ -d "$ALVO" ] || { echo "alvo não é diretório: $ALVO" >&2; exit 1; }
# --docs-dir é relativo à raiz do projeto: absoluto ou com .. é erro, alto e cedo.
case "$DOCS_DIR" in
    /*|*..*|"") echo "--docs-dir deve ser relativo à raiz do projeto (ex.: docs): $DOCS_DIR" >&2; exit 1 ;;
esac
DOCS_DIR="${DOCS_DIR%/}"
ALVO="$(cd "$ALVO" && pwd)"
RAIZ_CANONICA="${RAIZ_CANONICA:-$ALVO}"
[ -f "$PERFIL" ] || { echo "perfil inexistente: $PERFIL" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 (>= 3.11) é obrigatório para o guard" >&2; exit 1; }

# Validar entradas e fronteira antes de criar qualquer arquivo no projeto.
python3 - "$ALVO" "$PERFIL" "$AGENTES" <<'PYVALIDA'
import sys
import tomllib
from pathlib import Path
root, profile, agents = sys.argv[1:]
try:
    with open(profile, 'rb') as stream:
        tomllib.load(stream)
    unknown = set(agents.split(',')) - {'claude', 'codex', 'opencode', 'antigravity'}
    if unknown:
        raise ValueError('agentes desconhecidos: ' + ', '.join(sorted(unknown)))
    for name in ('.harness', '.githooks', 'scripts', 'docs', '.agents', '.agents/rules',
                 '.agents/workflows', '.codex', '.opencode', '.opencode/plugins',
                 '.opencode/commands', '.claude'):
        path = Path(root) / name
        if path.is_symlink():
            raise ValueError(f'diretório de instalação é symlink: {name}')
except (OSError, ValueError) as error:
    print(f'instalação recusada: {error}', file=sys.stderr)
    sys.exit(1)
PYVALIDA
[ $? -eq 0 ] || exit 1
case "$GIT_PROFILE" in portable|github-rust-node) ;; *) echo "perfil Git desconhecido: $GIT_PROFILE" >&2; exit 1 ;; esac
HARNESS_CONFIG="$PERFIL" python3 "$KIT/core/harness_guard.py" config harness.escape_env >/dev/null || exit 1

# A fonte do kit tem de estar em dia antes de copiar dela.
python3 "$KIT/scripts/sincronizar.py" --verificar >/dev/null || {
    echo "o kit está dessincronizado — rode: python3 $KIT/scripts/sincronizar.py" >&2; exit 1; }

tem() { case ",$AGENTES," in *",$1,"*) return 0 ;; esac; return 1; }
CRIADOS=(); IGUAIS=(); CONFLITOS=()

# instala <origem> <destino-relativo> [modo]
instala() {
    local origem="$1" rel="$2" modo="${3:-}" dest="$ALVO/$2"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if cmp -s "$origem" "$dest"; then IGUAIS+=("$rel"); else CONFLITOS+=("$rel"); fi
        return
    fi
    CRIADOS+=("$rel")
    [ $VERIFICAR -eq 1 ] && return
    local check_path="$dest"
    while [ "$check_path" != "$ALVO" ]; do
        [ -L "$check_path" ] && { echo "instalação recusada: caminho atravessa symlink: $rel" >&2; exit 1; }
        check_path="${check_path%/*}"
    done
    mkdir -p "$(dirname "$dest")" || exit 1
    cp "$origem" "$dest" || exit 1
    if [ -n "$modo" ]; then chmod "$modo" "$dest" || exit 1; fi
}

# instala_texto <conteúdo> <destino-relativo>
instala_texto() {
    local tmp; tmp=$(mktemp); printf '%s' "$1" > "$tmp"; instala "$tmp" "$2"; rm -f "$tmp"
}

# link <alvo-do-link> <destino-relativo>
link() {
    local alvo_link="$1" rel="$2" dest="$ALVO/$2"
    if [ -L "$dest" ]; then
        [ "$(readlink "$dest")" = "$alvo_link" ] && IGUAIS+=("$rel") || CONFLITOS+=("$rel (symlink para $(readlink "$dest"))")
        return
    fi
    [ -e "$dest" ] && { CONFLITOS+=("$rel (existe e não é symlink)"); return; }
    CRIADOS+=("$rel -> $alvo_link")
    [ $VERIFICAR -eq 1 ] && return
    mkdir -p "$(dirname "$dest")"; ln -s "$alvo_link" "$dest"
}

# ---------------------------------------------------------------- núcleo
instala "$KIT/core/harness_guard.py" ".harness/harness_guard.py" 755
instala "$KIT/core/documentation.py" ".harness/documentation.py" 755
instala "$KIT/core/validation.py" ".harness/validation.py" 755
# Verificadores instalados para uso do projeto (a skill doc-governance os
# referencia por este caminho; o gate abaixo os executa já instalados).
instala "$KIT/scripts/verificar_refs.py" ".harness/verificar_refs.py" 755
instala "$KIT/scripts/verificar_adr.py" ".harness/verificar_adr.py" 755
instala "$PERFIL" ".harness.toml"

# ---------------------------------------------------------------- git
if [ $COM_GIT -eq 1 ]; then
  if [ "$GIT_PROFILE" = portable ]; then
    instala "$KIT/templates/git/pre-push-portable" ".githooks/pre-push" 755
    instala "$KIT/templates/git/pre-commit-portable" ".githooks/pre-commit" 755
  else
    instala "$KIT/core/github_checks.py" ".harness/github_checks.py" 755
    instala "$KIT/templates/radar.example.tsv" ".harness/radar.tsv"   # lido pelo pre-push do kit
    instala "$KIT/templates/git/pre-push" ".githooks/pre-push" 755
    instala "$KIT/templates/git/pre-commit" ".githooks/pre-commit" 755
    instala "$KIT/templates/git/merge_gate.sh" "scripts/merge_gate.sh" 755
    instala "$KIT/templates/git/test_merge_gate_base.sh" ".agents/test_merge_gate_base.sh" 755
    instala "$KIT/templates/git/quadro.sh" ".agents/quadro.sh" 755
    instala "$KIT/templates/git/test_quadro.sh" ".agents/test_quadro.sh" 755
  fi
fi

# ---------------------------------------------------------------- docs
# Só o AGENTS.md instalado é reescrito (diretório de docs + nome do projeto).
if [ $COM_DOCS -eq 1 ]; then
    AGENTS_TXT="$(sed "s|docs/|${DOCS_DIR}/|g" "$KIT/templates/docs/AGENTS.md")"
    [ -n "$PROJECT_NAME" ] && AGENTS_TXT="$(printf '%s' "$AGENTS_TXT" | sed "s|<nome do projeto>|${PROJECT_NAME}|g")"
    instala_texto "$AGENTS_TXT" "AGENTS.md"
    link "AGENTS.md" "CLAUDE.md"
    link "AGENTS.md" "GEMINI.md"
    while IFS= read -r f; do
        rel="${f#"$KIT/templates/docs/"}"
        case "$rel" in AGENTS.md|agents/*) continue ;; esac
        instala "$f" "$DOCS_DIR/$rel"
    done < <(find "$KIT/templates/docs" -type f -name '*.md' | sort)
    instala "$KIT/templates/docs/agents/agents_work.md" ".agents/agents_work.md"
fi

# ---------------------------------------------------------------- skills (padrão: .agents/skills)
# `.agents/skills/` é o local canônico, qualquer que seja o agente (ADR-057 do projeto de
# origem): Codex e OpenCode o leem nativamente. O Claude Code só descobre `.claude/skills`,
# então ele vira symlink para `../.agents/skills` — medido: o Claude segue o symlink.
if [ -n "$SKILLS_EXISTENTES" ]; then
    link "$SKILLS_EXISTENTES" ".agents/skills"
elif [ $SEM_SKILLS -eq 0 ]; then
    while IFS= read -r f; do
        instala "$f" ".agents/skills/${f#"$KIT/skills/"}"
    done < <(find "$KIT/skills" -type f -name '*.md' | sort)
fi
if tem claude; then
    link "../.agents/skills" ".claude/skills"
fi

# ---------------------------------------------------------------- Codex
if tem codex; then
    GUARD_ABS="$RAIZ_CANONICA/.harness/harness_guard.py"
    HOOK_JSON=$(python3 - "$KIT/plugins/codex/hooks.json" "$GUARD_ABS" <<'PYHOOK'
import json
import shlex
import sys
with open(sys.argv[1]) as stream:
    data = json.load(stream)
for groups in data['hooks'].values():
    for group in groups:
        for hook in group['hooks']:
            hook['command'] = hook['command'].replace('"__HARNESS_GUARD__"', shlex.quote(sys.argv[2]))
print(json.dumps(data, ensure_ascii=False, indent=2))
PYHOOK
) || exit 1
    instala_texto "$HOOK_JSON
" ".codex/hooks.json"
fi

# ---------------------------------------------------------------- OpenCode
if tem opencode; then
    instala "$KIT/plugins/opencode/sovereign-harness.ts" ".opencode/plugins/sovereign-harness.ts"
    for c in "$KIT"/commands/*.md; do instala "$c" ".opencode/commands/$(basename "$c")"; done
fi

# ---------------------------------------------------------------- Antigravity
if tem antigravity; then
    # O ponteiro para o AGENTS.md só entra se o projeto ainda não tiver uma regra
    # always_on que o cite — duas regras dizendo a mesma coisa é ruído no contexto.
    ja_tem_ponteiro=0
    # `.agents/rules` e `.agents/workflows` são o padrão; `.agent/` só é lido para não
    # duplicar o ponteiro de um projeto que ainda o use.
    for r in "$ALVO"/.agent/rules/*.md "$ALVO"/.agents/rules/*.md; do
        [ -f "$r" ] && grep -q '^trigger: always_on' "$r" && grep -q 'AGENTS.md' "$r" \
            && [ "$(basename "$r")" != "sovereign-00-agents-md.md" ] && ja_tem_ponteiro=1
    done
    for r in "$KIT"/plugins/antigravity/rules/*.md; do
        [ "$(basename "$r")" = "00-agents-md.md" ] && [ $ja_tem_ponteiro -eq 1 ] && continue
        instala "$r" ".agents/rules/sovereign-$(basename "$r")"
    done
    for w in "$KIT"/plugins/antigravity/workflows/*.md; do instala "$w" ".agents/workflows/$(basename "$w")"; done
fi

# ---------------------------------------------------------------- refs dos docs
# O instalador garante o que instalou: os docs recém-escritos têm de passar nos
# verificadores. Roda as CÓPIAS INSTALADAS (.harness/) — prova que o entregue
# funciona no projeto, não só no kit. Saída é aviso (não muda o exit): projeto
# real ganha refs próprias depois, e a disciplina contínua vive na skill
# doc-governance.
REFS_MSG=""; ADR_MSG=""
if [ $COM_DOCS -eq 1 ] && [ $VERIFICAR -eq 0 ]; then
    if REFS_OUT=$(python3 "$ALVO/.harness/verificar_refs.py" --docs "$ALVO/$DOCS_DIR" --raiz "$ALVO" 2>&1); then
        REFS_MSG="refs em $DOCS_DIR: em dia"
    else
        REFS_MSG="refs em $DOCS_DIR: QUEBRADAS (instalação fresca deveria ser verde — reporte ao kit):\n$REFS_OUT"
    fi
    if ADR_OUT=$(python3 "$ALVO/.harness/verificar_adr.py" --adr-dir "$ALVO/$DOCS_DIR/adr" 2>&1); then
        ADR_MSG="adr em $DOCS_DIR: em dia"
    else
        ADR_MSG="adr em $DOCS_DIR: QUEBRADO (instalação fresca deveria ser verde — reporte ao kit):\n$ADR_OUT"
    fi
fi

# ---------------------------------------------------------------- relatório
echo ""
echo "━━━ harness Sovereign → $ALVO $([ $VERIFICAR -eq 1 ] && echo '(--verificar: nada foi escrito)')"
echo "criados:    ${#CRIADOS[@]}"; printf '   + %s\n' "${CRIADOS[@]+"${CRIADOS[@]}"}"
echo "já iguais:  ${#IGUAIS[@]}"
[ -n "$REFS_MSG" ] && printf '%b\n' "$REFS_MSG"
[ -n "$ADR_MSG" ] && printf '%b\n' "$ADR_MSG"
if [ ${#CONFLITOS[@]} -gt 0 ]; then
    echo "CONFLITOS:  ${#CONFLITOS[@]} (não sobrescritos — compare e mescle à mão)"
    printf '   ! %s\n' "${CONFLITOS[@]}"
    printf '%s\n' "${CONFLITOS[@]}" | grep -q '^\.claude/skills' && \
        echo "   → .claude/skills é diretório real: mova as skills para .agents/skills e troque-o pelo symlink ../.agents/skills"
fi
echo ""
echo "Próximos passos (decisão de quem instala):"
[ $COM_GIT -eq 1 ] && echo "  • ativar os gates de git neste clone:   git -C \"$ALVO\" config core.hooksPath \"$ALVO/.githooks\""
tem claude && {
    echo "  • Claude Code:  claude plugin marketplace add \"$KIT\""
    echo "                  claude plugin install sovereign-harness-guard@sovereign-harness --scope project"
    echo "                  (skills: pelo symlink .claude/skills -> ../.agents/skills; o plugin de método é opcional)"
}
tem codex && echo "  • Codex: abra o codex no projeto e APROVE a revisão dos hooks (.codex/hooks.json) — sem isso eles não rodam."
tem opencode && echo "  • OpenCode: o plugin carrega sozinho de .opencode/plugins/ na próxima sessão."
tem antigravity && echo "  • Antigravity: reinicie o IDE e confirme a injeção da regra com um canário (ver USO)."
echo "  • conferir as regras ativas:  python3 \"$ALVO/.harness/harness_guard.py\" regras"
[ ${#CONFLITOS[@]} -gt 0 ] && exit 3
exit 0
