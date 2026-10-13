#!/usr/bin/env python3
"""Monta os plugins a partir da FONTE ÚNICA do kit — e verifica que estão em dia.

Plugins de agente são diretórios autocontidos (o Claude Code copia o plugin para
um cache; um symlink para fora dele quebra). Então guard, skills e comandos são
COPIADOS da fonte para cada plugin. Cópia que diverge da fonte é exatamente o
defeito "o mesmo arquivo em N lugares, sete com o fix e um sem" — por isso o
modo --verificar existe e roda nos testes.

    python3 scripts/sincronizar.py              # gera/atualiza as cópias
    python3 scripts/sincronizar.py --verificar  # exit 1 se alguma cópia divergir

Fontes:  core/harness_guard.py · skills/* · commands/*.md · core (regras)
Destinos:
  plugins/claude-code/sovereign-harness-guard/{scripts/harness_guard.py, commands/}
  plugins/claude-code/sovereign-harness-metodo/skills/
  plugins/codex/sovereign-harness/skills/
  plugins/opencode/harness_guard.py
  plugins/antigravity/workflows/*.md  (dos comandos)
  plugins/antigravity/rules/10-guardrails.md  (da tabela de regras do guard)
"""
from __future__ import annotations

import importlib.util
import re
import shutil
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
GUARD = KIT / "core" / "harness_guard.py"
SKILLS = KIT / "skills"
COMANDOS = KIT / "commands"
P = KIT / "plugins"


def _carregar_guard():
    spec = importlib.util.spec_from_file_location("harness_guard", GUARD)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    sys.modules[spec.name] = mod  # dataclass com anotações adiadas resolve pelo módulo registrado
    spec.loader.exec_module(mod)
    return mod


def workflow_antigravity(texto: str) -> str:
    """Comando → workflow do Antigravity: mantém só `description` no frontmatter
    e troca `$ARGUMENTS` (que o Antigravity não substitui) por texto."""
    m = re.match(r"^---\n(.*?)\n---\n", texto, re.S)
    if not m:
        return texto
    desc = [l for l in m.group(1).splitlines() if l.startswith("description:")]
    corpo = texto[m.end():].replace("$ARGUMENTS", "(o que o usuário pediu ao acionar este workflow)")
    return "---\n" + "\n".join(desc) + "\n---\n" + corpo


def regra_guardrails_antigravity() -> str:
    g = _carregar_guard()
    linhas = [
        "---",
        "trigger: always_on",
        "---",
        "",
        "# Guardrails do método Sovereign (Antigravity)",
        "",
        "O Antigravity não tem hook que bloqueie uma ação antes de executar, como o Claude Code, o Codex e o",
        "OpenCode têm. Aqui as mesmas regras valem por instrução — e os gates do git (pre-commit, pre-push,",
        "merge gate) continuam bloqueando de verdade no commit, no push e no merge.",
        "",
        "**Antes de executar um comando ou editar um arquivo, confira se ele cai numa destas classes.** Se cair,",
        "não execute: faça do jeito certo descrito na skill indicada, ou peça ao dono a exceção nominal.",
        "",
        "| Regra | O que é proibido | Origem |",
        "|---|---|---|",
    ]
    for r in g.REGRAS:
        linhas.append(f"| `{r.id}` | {r.titulo} | {r.origem} |")
    linhas += [
        "",
        "Para conferir um comando antes de rodar (mesma decisão dos outros agentes):",
        "",
        "```bash",
        'python3 .harness/harness_guard.py checar --cmd "<comando>"',
        "```",
        "",
        "Skills do método: `.agents/skills/` (leia `disciplina-de-validacao` e `vies-de-plausibilidade`",
        "no início de qualquer tarefa que termine em push).",
        "",
    ]
    return "\n".join(linhas)


def plano() -> dict[Path, bytes]:
    """Tudo que deveria existir nos destinos, com o conteúdo esperado."""
    alvo: dict[Path, bytes] = {}
    guard = GUARD.read_bytes()
    alvo[P / "claude-code/sovereign-harness-guard/scripts/harness_guard.py"] = guard
    alvo[P / "opencode/harness_guard.py"] = guard
    for cmd in sorted(COMANDOS.glob("*.md")):
        alvo[P / "claude-code/sovereign-harness-guard/commands" / cmd.name] = cmd.read_bytes()
        alvo[P / "antigravity/workflows" / cmd.name] = workflow_antigravity(cmd.read_text("utf-8")).encode()
    for arq in sorted(SKILLS.rglob("*")):
        if arq.is_file() and "__pycache__" not in arq.parts:
            rel = arq.relative_to(SKILLS)
            alvo[P / "claude-code/sovereign-harness-metodo/skills" / rel] = arq.read_bytes()
            alvo[P / "codex/sovereign-harness/skills" / rel] = arq.read_bytes()
    alvo[P / "antigravity/rules/10-guardrails.md"] = regra_guardrails_antigravity().encode()
    return alvo


GERADOS = [
    P / "claude-code/sovereign-harness-guard/commands",
    P / "claude-code/sovereign-harness-metodo/skills",
    P / "codex/sovereign-harness/skills",
    P / "antigravity/workflows",
]


def sobrando(alvo: dict[Path, bytes]) -> list[Path]:
    extras = []
    for d in GERADOS:
        if d.exists():
            extras += [f for f in d.rglob("*") if f.is_file() and f not in alvo]
    return extras


def main(argv: list[str]) -> int:
    alvo = plano()
    if "--verificar" in argv:
        divergentes = [p for p, c in alvo.items() if not p.exists() or p.read_bytes() != c]
        extras = sobrando(alvo)
        for p in divergentes:
            print(f"desatualizado: {p.relative_to(KIT)}")
        for p in extras:
            print(f"sobrando (fonte apagada?): {p.relative_to(KIT)}")
        if divergentes or extras:
            print("rode: python3 scripts/sincronizar.py")
            return 1
        print(f"em dia: {len(alvo)} cópia(s) idênticas à fonte")
        return 0
    for p in sobrando(alvo):
        p.unlink()
    for p, c in alvo.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        if not p.exists() or p.read_bytes() != c:
            p.write_bytes(c)
    shutil.copymode(GUARD, P / "claude-code/sovereign-harness-guard/scripts/harness_guard.py")
    print(f"sincronizado: {len(alvo)} arquivo(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
