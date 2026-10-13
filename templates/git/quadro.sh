#!/usr/bin/env bash
# =============================================================================
# Quadro de Trabalho — helper de acesso e commit
# =============================================================================
# O quadro (`.agents/agents_work.md`) só cumpre a função dele se TODAS as
# sessões lerem e escreverem o MESMO arquivo. Duas armadilhas tornam isso menos
# óbvio do que parece:
#
#   1. Cada `git worktree` tem a própria cópia do arquivo. Editar a cópia do seu
#      worktree é escrever num quadro que ninguém mais lê — e que vai conflitar
#      no merge. O canônico é sempre o do diretório principal do meta-repo.
#
#   2. O meta-repo é compartilhado, e outra sessão pode ter dezenas de arquivos
#      STAGED no index dele. Um `git commit` comum levaria o trabalho dela junto.
#      `git commit <path>` commita apenas o caminho dado e deixa o index intacto
#      — verificado em 2026-09-09 com index sujo de propósito.
#
# Uso:
#     .agents/quadro.sh ler              # mostra o quadro (SEMPRE a versão de main)
#     .agents/quadro.sh editar           # prepara um arquivo de trabalho e imprime o caminho
#     .agents/quadro.sh agora            # timestamp UTC no formato do quadro
#     .agents/quadro.sh commit "<msg>"   # commita o arquivo de trabalho em main
#     .agents/quadro.sh caminho          # imprime o caminho canônico em disco
#
# Terceira armadilha, medida em 2026-09-10: o arquivo em disco pertence à branch
# que estiver em checkout no diretório principal. Se outra sessão trocou a branch
# ali, o que está em disco é a versão DAQUELA branch — ler dali entrega um quadro
# desatualizado sem nenhum aviso. Por isso `ler` e `editar` extraem de `main`, e
# não do disco.
# =============================================================================
set -uo pipefail

# QUADRO_META_REPO e QUADRO_RASCUNHO existem só para o teste hermético
# (.agents/test_quadro.sh), que roda contra um repositório descartável.
# Repositório de coordenação: QUADRO_META_REPO, senão o `[quadro].canonico` do
# .harness.toml (pelo guard), senão o diretório acima deste script. Chamado a
# partir da cópia de um worktree, só os dois primeiros acertam o canônico.
_canonico() {
    local g
    for g in "$(dirname "$0")/../.harness/harness_guard.py" "${HARNESS_GUARD:-}"; do
        [ -f "$g" ] && python3 "$g" config quadro.canonico 2>/dev/null && return 0
    done
    return 1
}
if [ -n "${QUADRO_META_REPO:-}" ]; then
    META_REPO="$QUADRO_META_REPO"
elif c=$(_canonico) && [ -n "$c" ]; then
    META_REPO="${c%/.agents/agents_work.md}"
else
    META_REPO="$(cd "$(dirname "$0")/.." && pwd)"
fi
QUADRO="$META_REPO/.agents/agents_work.md"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

RASCUNHO="${QUADRO_RASCUNHO:-${TMPDIR:-/tmp}/sovereign-quadro-$(id -u).md}"
# Ao lado do rascunho, o SHA de main de onde ele saiu. Sem isso não há como saber
# se um rascunho é de agora ou de horas atrás — e o caminho é um só por usuário,
# então pode ter sido deixado por outra sessão.
BASE_DO_RASCUNHO="$RASCUNHO.base"

git -C "$META_REPO" rev-parse main >/dev/null 2>&1 || {
    echo -e "${RED}meta-repo sem branch main em $META_REPO${NC}"; exit 1;
}

# Onde editar: se o diretório principal está em `main`, o arquivo em disco JÁ é a
# versão certa e edita-se ele. Se está na branch de outra sessão, o disco tem a
# versão dela — então o trabalho acontece num rascunho fora do repo, para não
# sujar a working tree alheia.
alvo_de_edicao() {
    if [ "$(git -C "$META_REPO" branch --show-current)" = "main" ]; then
        echo "$QUADRO"
    else
        echo "$RASCUNHO"
    fi
}

# Com o meta-repo fora de main, o disco é da branch de outra sessão e o helper
# não o lê: o commit sai do rascunho. Uma edição feita no disco some do commit
# — foi o erro de 2026-09-12 (e371cab). Aviso não bastou; agora recusa, com
# escape nomeado para o caso consciente.
recusar_disco_editado() {
    local branch
    branch=$(git -C "$META_REPO" branch --show-current)
    [ "$branch" = "main" ] && return 0
    if ! git -C "$META_REPO" diff --quiet -- .agents/agents_work.md 2>/dev/null; then
        case ",${HARNESS_SKIP:-}," in
            *,quadro-disco,*|*,all,*)
                echo -e "${YELLOW}⏭  quadro-disco: edição no disco ignorada por escape consciente — NÃO entra neste commit.${NC}"
                return 0
                ;;
        esac
        echo -e "${RED}o arquivo em disco ($QUADRO) tem edição não commitada, mas com o meta-repo fora de main o commit sai do rascunho ($RASCUNHO) — a edição do disco NÃO entraria e sumiria do seu radar.${NC}"
        echo -e "${RED}Copie o que importa para o rascunho (quadro.sh editar de novo, se preciso) e rode commit outra vez. Escape consciente: HARNESS_SKIP=quadro-disco.${NC}"
        exit 1
    fi
}

case "${1:-}" in
    caminho) echo "$QUADRO" ;;
    ler)     git -C "$META_REPO" show main:.agents/agents_work.md ;;
    editar)
        alvo=$(alvo_de_edicao)
        # O alvo pode conter edição não commitada — sua ou de outra sessão
        # (o rascunho é um só por usuário). Extrair de main por cima apagaria
        # sem aviso (medido em 2026-09-12, duas vezes no mesmo dia). Recusa em
        # vez de presumir.
        if [ "$alvo" = "$RASCUNHO" ]; then
            if [ -f "$alvo" ] && ! git -C "$META_REPO" show main:.agents/agents_work.md 2>/dev/null | diff -q - "$alvo" >/dev/null 2>&1; then
                echo -e "${RED}o rascunho ($alvo) tem conteúdo não commitado — extrair de main agora o apagaria.${NC}"
                echo -e "${RED}Commite-o primeiro (quadro.sh commit \"<msg>\") ou apague-o (rm) e rode editar de novo.${NC}"
                exit 1
            fi
        else
            # Em main o disco É o quadro vivo: só segue sem edição pendente.
            # (Estar atrás de main é impossível aqui — checkout em main e HEAD
            # são o mesmo ref; se diferir, é edição sua não commitada.)
            if ! git -C "$META_REPO" diff --quiet HEAD -- .agents/agents_work.md 2>/dev/null; then
                echo -e "${RED}o quadro em disco tem edição não commitada — extrair de main agora a apagaria.${NC}"
                echo -e "${RED}Commite-a primeiro (quadro.sh commit \"<msg>\") ou descarte-a (git checkout -- .agents/agents_work.md) e rode editar de novo.${NC}"
                exit 1
            fi
        fi
        git -C "$META_REPO" show main:.agents/agents_work.md > "$alvo" || exit 1
        if [ "$alvo" = "$RASCUNHO" ]; then
            git -C "$META_REPO" rev-parse main > "$BASE_DO_RASCUNHO" || exit 1
        fi
        echo -e "${GREEN}edite este arquivo e depois rode 'quadro.sh commit \"<msg>\"':${NC}"
        echo "$alvo"
        ;;
    agora)   date -u '+%F %H:%M' ;;
    commit)
        msg="${2:-}"
        [ -n "$msg" ] || { echo -e "${RED}uso: $0 commit \"<mensagem>\"${NC}"; exit 1; }

        main_sha=$(git -C "$META_REPO" rev-parse main 2>/dev/null) || {
            echo -e "${RED}não achei a branch main do meta-repo${NC}"; exit 1;
        }

        # O arquivo de trabalho não pode estar ATRÁS do que já existe em main: isso
        # aconteceria se main tivesse recebido uma atualização de outra sessão
        # depois de você ter lido o arquivo. Commitar por cima apagaria o que ela
        # escreveu — e é justamente o modo de perda silenciosa que este projeto
        # já mediu (branch em dia sobrescrevendo com conteúdo antigo).
        #
        # Até 2026-09-12 o código abaixo só conferia igualdade, e este comentário
        # prometia mais do que o código fazia: um rascunho deixado por outra sessão
        # horas antes subiu por cima de main e apagou 46 linhas do quadro (00275f4).
        # Agora o rascunho carrega a base, e o commit a confere. Com main em
        # checkout o disco é o próprio quadro vivo, e a checagem não se aplica.
        fonte=$(alvo_de_edicao)
        [ -f "$fonte" ] || { echo -e "${RED}nada para commitar: rode 'quadro.sh editar' primeiro${NC}"; exit 1; }

        recusar_disco_editado

        if [ "$fonte" = "$RASCUNHO" ]; then
            [ -f "$BASE_DO_RASCUNHO" ] || {
                echo -e "${RED}o rascunho $RASCUNHO não tem registro de base — pode ser de outra sessão ou de outra hora. Rode 'quadro.sh editar' e refaça sua edição.${NC}"
                exit 1
            }
            base=$(cat "$BASE_DO_RASCUNHO")
            if [ "$base" != "$main_sha" ]; then
                echo -e "${RED}o rascunho foi gerado a partir de main ${base:0:7}, e main agora é ${main_sha:0:7}. Commitar apagaria o que entrou nesse intervalo. Rode 'quadro.sh editar' e refaça sua edição.${NC}"
                exit 1
            fi
        fi

        if git -C "$META_REPO" show main:.agents/agents_work.md 2>/dev/null | diff -q - "$fonte" >/dev/null 2>&1; then
            echo -e "${YELLOW}o quadro não tem alterações em relação a main — nada a commitar.${NC}"
            exit 0
        fi

        branch=$(git -C "$META_REPO" branch --show-current)
        if [ "$branch" = "main" ]; then
            # Caminho normal: `git commit <path>` leva só o quadro e preserva o
            # que estiver staged de outras sessões.
            sujos=$(git -C "$META_REPO" status --short | grep -cv 'agents_work.md' || true)
            [ "$sujos" -gt 0 ] && echo -e "${YELLOW}nota: ${sujos} outro(s) arquivo(s) alterados no meta-repo (de outra sessão) NÃO entram neste commit.${NC}"
            git -C "$META_REPO" commit -q .agents/agents_work.md -m "$msg" || {
                echo -e "${RED}commit falhou${NC}"; exit 1;
            }
        else
            # O diretório principal está na branch de outra sessão. Trocar a branch
            # dela para commitar seria sequestrar o trabalho alheio; deixar o quadro
            # sem registro até ela terminar seria travar o mecanismo por horas.
            #
            # Saída: escrever o commit em `main` por plumbing, sem tocar no working
            # tree nem no index compartilhado. O `update-ref` com o valor esperado
            # (compare-and-swap) recusa se `main` tiver avançado nesse intervalo.
            echo -e "${YELLOW}meta-repo está em '${branch}' (outra sessão). Commitando em main por plumbing, sem tocar no working tree dela.${NC}"
            blob=$(git -C "$META_REPO" hash-object -w "$fonte") || exit 1
            idx=$(mktemp) || exit 1
            trap 'rm -f "$idx"' EXIT
            GIT_INDEX_FILE="$idx" git -C "$META_REPO" read-tree main || exit 1
            GIT_INDEX_FILE="$idx" git -C "$META_REPO" update-index --add \
                --cacheinfo "100644,${blob},.agents/agents_work.md" || exit 1
            tree=$(GIT_INDEX_FILE="$idx" git -C "$META_REPO" write-tree) || exit 1
            novo=$(git -C "$META_REPO" commit-tree "$tree" -p main -m "$msg") || exit 1
            git -C "$META_REPO" update-ref refs/heads/main "$novo" "$main_sha" || {
                echo -e "${RED}main avançou durante a operação — releia o quadro e refaça sua edição.${NC}"
                exit 1
            }
        fi
        # A base foi consumida: o próximo commit exige um `editar` novo.
        [ "$fonte" = "$RASCUNHO" ] && rm -f "$BASE_DO_RASCUNHO"
        echo -e "${GREEN}✅ quadro commitado em main:${NC} $(git -C "$META_REPO" log --oneline -1 main)"
        ;;
    *)
        sed -n '/^# Uso:/,/^# ==/p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
