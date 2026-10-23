#!/usr/bin/env bash
# =============================================================================
# Teste hermético do quadro.sh, contra um meta-repo DESCARTÁVEL.
#
# Uso:  .agents/test_quadro.sh [caminho-do-helper]     (padrão: o quadro.sh ao lado)
#
# Nunca toca o meta-repo real: tudo roda num diretório temporário, com o helper
# apontado para ele por QUADRO_META_REPO. O cenário C1 é o incidente de
# 2026-09-12 (00275f4): um rascunho velho subiu por cima de main e apagou o que
# outra sessão tinha commitado nesse meio-tempo.
# =============================================================================
set -uo pipefail

HELPER=$(realpath "${1:-$(dirname "$0")/quadro.sh}") || exit 1
# Sem esta guarda, um caminho errado faz todo comando falhar — e toda recusa
# esperada "passa". Aconteceu na primeira execução deste teste.
[ -x "$HELPER" ] || { echo "helper inexistente ou sem permissão de execução: $HELPER"; exit 2; }
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT

export QUADRO_META_REPO="$T/meta"
export TMPDIR="$T/tmp"
unset QUADRO_RASCUNHO
# Identidade só do processo de teste — nenhuma configuração de git é alterada.
export GIT_AUTHOR_NAME=teste GIT_AUTHOR_EMAIL=teste@exemplo.invalid
export GIT_COMMITTER_NAME=teste GIT_COMMITTER_EMAIL=teste@exemplo.invalid
mkdir -p "$TMPDIR"

case "$QUADRO_META_REPO" in "$T"/*) ;; *) echo "repo de teste fora do diretório temporário — abortando"; exit 2 ;; esac

git init -q -b main "$QUADRO_META_REPO" || exit 1
cd "$QUADRO_META_REPO" || exit 1
git config core.hooksPath /dev/null   # config LOCAL do repo descartável
mkdir .agents
printf '# Quadro\n\n## Em andamento\n\nlinha-original\n' > .agents/agents_work.md
git add .agents/agents_work.md && git commit -qm base
git checkout -qb outra-sessao   # meta-repo fora de main: o helper usa rascunho

falhas=0
ok()  { echo "✅ $1"; }
nok() { echo "❌ $1"; falhas=$((falhas + 1)); }
main_tem() { git show main:.agents/agents_work.md | grep -q "$1"; }

# C1 — o incidente: gero o rascunho, outra sessão commita em main, eu commito o meu.
R=$("$HELPER" editar | tail -1)
QUADRO_RASCUNHO="$TMPDIR/outra.md" "$HELPER" editar > /dev/null
echo "entrada-da-outra-sessao" >> "$TMPDIR/outra.md"
QUADRO_RASCUNHO="$TMPDIR/outra.md" "$HELPER" commit "outra sessão" > /dev/null 2>&1
main_tem entrada-da-outra-sessao || nok "C1: preparo — a outra sessão não conseguiu commitar"
echo "minha-edicao" >> "$R"
saida=$("$HELPER" commit "minha" 2>&1) && nok "C1: commitou o rascunho velho" || {
    echo "$saida" | grep -q "main agora é" && ok "C1: recusou o rascunho velho, dizendo por quê" || nok "C1: falhou, mas não pela base: $saida"; }
main_tem entrada-da-outra-sessao && ok "C1: a entrada da outra sessão sobreviveu" || nok "C1: a entrada da outra sessão SUMIU"

# C2 — o fluxo certo: editar agora, editar o arquivo, commitar.
# (Limpa o rascunho recusado do C1: com a guarda nova, `editar` não extrai
# por cima de conteúdo não commitado — esse caso é o C6, já provado acima.)
rm -f "$R" "$R.base"
R=$("$HELPER" editar | tail -1)
echo "edicao-fresca" >> "$R"
if "$HELPER" commit "fresca" > /dev/null 2>&1 && main_tem edicao-fresca && main_tem entrada-da-outra-sessao; then
    ok "C2: rascunho fresco commitado, nada perdido"
else
    nok "C2: o fluxo certo falhou"
fi

# C3 — reusar o rascunho depois do commit (a base foi consumida).
echo "reuso" >> "$R"
saida=$("$HELPER" commit "reuso" 2>&1) && nok "C3: aceitou rascunho sem base" || {
    echo "$saida" | grep -q "não tem registro de base" && ok "C3: recusou rascunho sem base, dizendo por quê" || nok "C3: falhou, mas não pela base: $saida"; }

# C6 — editar com rascunho sujo (edição não commitada de outra sessão ou
# anterior): recusa em vez de extrair por cima. O rascunho ainda tem o
# "reuso" do C3, não commitado.
saida=$("$HELPER" editar 2>&1) && nok "C6: extraiu por cima de rascunho sujo" || {
    echo "$saida" | grep -q "tem conteúdo não commitado" && ok "C6: recusou rascunho sujo, dizendo por quê" || nok "C6: falhou, mas não pelo rascunho: $saida"; }
grep -q "^reuso$" "$R" && ok "C6: conteúdo do rascunho preservado" || nok "C6: conteúdo do rascunho SUMIU"
rm -f "$R" "$R.base"

# C4 — editar o disco com o meta-repo fora de main e commitar o rascunho:
# a edição do disco NÃO entra, e agora o commit recusa em vez de só avisar.
echo "editei-o-disco" >> .agents/agents_work.md
"$HELPER" editar > /dev/null
echo "algo-no-rascunho" >> "$R"
saida=$("$HELPER" commit "nada" 2>&1) && nok "C4: commitou ignorando edição no disco" || {
    echo "$saida" | grep -q "NÃO entraria" && ok "C4: recusou por edição no disco, dizendo por quê" || nok "C4: falhou, mas não pelo disco: $saida"; }
git checkout -q -- .agents/agents_work.md
rm -f "$R" "$R.base"

# C5 — meta-repo em main: o fluxo direto no disco continua funcionando.
git checkout -q main
echo "direto-no-disco" >> .agents/agents_work.md
if "$HELPER" commit "disco" > /dev/null 2>&1 && main_tem direto-no-disco; then ok "C5: modo main segue funcionando"; else nok "C5: modo main quebrou"; fi

# C7 — em main, editar com disco sujo (edição sua ainda não commitada):
# recusa em vez de extrair por cima.
echo "edicao-minha-nao-commitada" >> .agents/agents_work.md
saida=$("$HELPER" editar 2>&1) && nok "C7: extraiu por cima de edição no disco" || {
    echo "$saida" | grep -q "edição não commitada" && ok "C7: recusou disco sujo, dizendo por quê" || nok "C7: falhou, mas não pelo disco: $saida"; }
grep -q "^edicao-minha-nao-commitada$" .agents/agents_work.md && ok "C7: edição no disco preservada" || nok "C7: edição no disco SUMIU"
git checkout -q -- .agents/agents_work.md

# ---- saude: o que está fora da main e o que está parado ------------------------
# Data fixa: o teste não pode depender do relógio.
export QUADRO_HOJE=2026-10-21 QUADRO_DIAS_PARADA=3
git checkout -q main
git branch -q -D outra-sessao   # branch dos cenários acima: não é objeto da saude

# S0 — estado limpo: nada a acusar, e --estrito passa.
saida=$("$HELPER" saude 2>&1); rc=$?
echo "$saida" | grep -q "nada fora da main" && [ $rc -eq 0 ] && ok "S0: estado limpo reportado como limpo" || nok "S0: estado limpo acusou algo: $saida"
"$HELPER" saude --estrito >/dev/null 2>&1 && ok "S0: --estrito passa no estado limpo" || nok "S0: --estrito reprovou o estado limpo"

# S1 — o caso do E67: doc commitada numa branch, sem entrada ativa no quadro.
git checkout -q -b claude/doc-orfa
mkdir -p docs && echo "adr nunca publicada" > docs/ADR-999.md
git add docs/ADR-999.md && git commit -qm "docs: adr so na branch"
git checkout -q main
saida=$("$HELPER" saude 2>&1); rc=$?
echo "$saida" | grep -q "SEM entrada ativa no quadro: claude/doc-orfa" && ok "S1: branch órfã com doc fora da main acusada" || nok "S1: branch órfã NÃO acusada: $saida"
[ $rc -eq 0 ] && ok "S1: sem --estrito não bloqueia" || nok "S1: bloqueou sem --estrito"
"$HELPER" saude --estrito >/dev/null 2>&1 && nok "S1: --estrito deixou passar a órfã" || ok "S1: --estrito reprova a órfã"

# S2 — a mesma branch com entrada ativa e commit recente: em curso, sem alerta.
printf '\n### claude/doc-orfa — trabalho\n- **Última atualização**: 2026-10-20 10:00 (UTC)\n' >> .agents/agents_work.md
git commit -qam "quadro: entrada ativa"
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "em curso (entrada ativa): claude/doc-orfa" && ok "S2: branch com entrada ativa vista como em curso" || nok "S2: classificação errada: $saida"
echo "$saida" | grep -q "SEM entrada ativa" && nok "S2: ainda acusou como órfã" || ok "S2: não acusou como órfã"

# S3 — publicada: o conteúdo entra na main (cherry-pick). Passa a "só falta apagar".
# (cherry-pick não tem -q; um preparo que falha em silêncio faria o S3 testar nada)
git cherry-pick claude/doc-orfa >/dev/null 2>&1 || nok "S3: preparo — cherry-pick falhou"
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "já publicadas na main" && echo "$saida" | grep -q "claude/doc-orfa" && ok "S3: branch publicada reconhecida (só falta apagar)" || nok "S3: publicada não reconhecida: $saida"
git branch -q -D claude/doc-orfa

# S4 — entrada parada: última data além do limite é acusada; a recente, não.
printf '\n### claude/velha — parada\n- **Última atualização**: 2026-10-01 10:00 (UTC)\n' >> .agents/agents_work.md
git commit -qam "quadro: entrada velha"
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "⚠ claude/velha — parada — última data 2026-10-01 (20d)" && ok "S4: entrada parada acusada com a idade" || nok "S4: entrada parada não acusada: $saida"
echo "$saida" | grep -q "⚠ claude/doc-orfa — trabalho" && nok "S4: acusou a entrada recente" || ok "S4: entrada recente não acusada"

# S5 — `ler`: stdout é o quadro, intacto; a saúde vai para stderr e pode ser desligada.
diff <("$HELPER" ler 2>/dev/null) <(git show main:.agents/agents_work.md) >/dev/null && ok "S5: stdout do ler é exatamente o quadro da main" || nok "S5: ler alterou o stdout"
"$HELPER" ler 2>&1 >/dev/null | grep -q "saúde do quadro" && ok "S5: saúde sai em stderr" || nok "S5: saúde não apareceu em stderr"
[ -z "$(QUADRO_SEM_SAUDE=1 "$HELPER" ler 2>&1 >/dev/null)" ] && ok "S5: QUADRO_SEM_SAUDE desliga" || nok "S5: QUADRO_SEM_SAUDE não desligou"


# S6 — edição não declarada no checkout principal (o caso de 2026-10-23: uma
# edição em lote sem "Paths sob edição" reescreveu 3 skills e ninguém viu).
echo "rascunho de alguém" > docs/solta.md
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "⚠ \[??\] docs/solta.md" && ok "S6a: arquivo novo não declarado acusado" || nok "S6a: não acusou o arquivo solto: $saida"
"$HELPER" saude --estrito >/dev/null 2>&1 && nok "S6a: --estrito deixou passar edição não declarada" || ok "S6a: --estrito reprova edição não declarada"
printf '\n### claude/dono-da-solta — escrevendo\n- **Última atualização**: 2026-10-20 10:00 (UTC)\n- **Paths sob edição**: `docs/solta.md`\n' >> .agents/agents_work.md
git commit -qam "quadro: declara docs/solta.md"
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "docs/solta.md" && nok "S6b: acusou arquivo declarado: $saida" || ok "S6b: arquivo declarado não é acusado"
echo "x" >> docs/ADR-999.md
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "⚠ \[M\] docs/ADR-999.md" && ok "S6c: arquivo rastreado modificado e não declarado acusado" || nok "S6c: modificado não acusado: $saida"
sed -i 's|`docs/solta.md`|`docs/`|' .agents/agents_work.md && git commit -qam "quadro: declara o diretório"
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "docs/ADR-999.md" && nok "S6d: diretório declarado não cobriu o arquivo: $saida" || ok "S6d: diretório declarado cobre os arquivos dentro dele"
echo "edicao-no-quadro" >> .agents/agents_work.md
saida=$("$HELPER" saude 2>&1)
echo "$saida" | grep -q "agents_work.md" && nok "S6e: acusou o próprio quadro" || ok "S6e: o próprio quadro sujo não é acusado"
git checkout -q -- .agents/agents_work.md docs/ADR-999.md && rm -f docs/solta.md

echo
if [ "$falhas" -eq 0 ]; then echo "TUDO OK"; else echo "$falhas falha(s)"; exit 1; fi
