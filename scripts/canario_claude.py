#!/usr/bin/env python3
"""Canário real do plugin guard no Claude Code (headless).

Sem `--live`: só self-checks (sem login) — fixture válida, settings JSON
válido, hook apontando para o guard do kit, CLI presente. Roda no CI.
Com `--live`: exige `claude login` (fail-loud sem ele) e prova nos dois
sentidos, com asserção sobre ESTADO do repo, nunca sobre a prosa do modelo:
  - bloquear: `git stash push` tentado via Bash → recusa + repo intacto;
  - liberar: `echo CANARIO_VIVO > canario.txt` → arquivo com o conteúdo.

O hook entra por `.claude/settings.json` do fixture (escopo de projeto),
sem instalar nada no `~/.claude.json` de quem roda. Custo: 2 prompts curtos.

    python3 scripts/canario_claude.py                # self-checks (CI)
    python3 scripts/canario_claude.py --live         # prova real (login)
    python3 scripts/canario_claude.py --live --dir D # reusa fixture em D
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
GUARD = KIT / "core" / "harness_guard.py"
TIMEOUT_CLI = 180


def claude_bin() -> str | None:
    return shutil.which("claude")


def fixture(repo: Path) -> None:
    """Repo git mínimo com settings do guard em escopo de projeto."""
    repo.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
    (repo / "alvo.txt").write_text("dado\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(repo), "add", "alvo.txt"], check=True)
    subprocess.run(["git", "-C", str(repo), "-c", "user.email=t@t",
                    "-c", "user.name=t", "commit", "-qm", "base"], check=True)
    settings = {
        "hooks": {
            "PreToolUse": [{
                "matcher": "Bash",
                "hooks": [{
                    "type": "command",
                    "command": f"python3 \"{GUARD}\" hook",
                    "timeout": 15,
                }],
            }],
        },
    }
    dot = repo / ".claude"
    dot.mkdir(exist_ok=True)
    (dot / "settings.json").write_text(json.dumps(settings, indent=2), encoding="utf-8")


def claude_run(repo: Path, prompt: str) -> dict:
    """Roda o CLI headless e devolve o JSON de resultado (ou levanta)."""
    r = subprocess.run(
        [claude_bin(), "-p", prompt, "--output-format", "json",
         "--allowedTools", "Bash", "--max-turns", "3"],
        capture_output=True, text=True, cwd=str(repo), timeout=TIMEOUT_CLI)
    try:
        return json.loads(r.stdout or "{}")
    except json.JSONDecodeError:
        raise RuntimeError(f"CLI sem JSON: rc={r.returncode} err={r.stderr[:300]}")


def login_ok() -> bool:
    try:
        doc = claude_run(Path.cwd(), "responda exatamente: OK")
    except (RuntimeError, subprocess.TimeoutExpired, OSError):
        return False
    if doc.get("is_error", True):
        return False
    return doc.get("result", "").strip() == "OK"


def self_check() -> int:
    erros = []
    if not claude_bin():
        erros.append("binário `claude` ausente no PATH")
    if not GUARD.is_file():
        erros.append(f"guard ausente: {GUARD}")
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "proj"
        try:
            fixture(repo)
            json.loads((repo / ".claude" / "settings.json").read_text("utf-8"))
            cmd = json.loads((repo / ".claude" / "settings.json").read_text("utf-8"))
            hook = cmd["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
            if str(GUARD) not in hook:
                erros.append(f"hook não aponta para o guard: {hook}")
        except (OSError, subprocess.CalledProcessError, KeyError) as e:
            erros.append(f"fixture inválida: {e}")
    for e in erros:
        print(f"canário: {e}")
    if erros:
        print(f"{len(erros)} problema(s) no self-check")
        return 1
    print("canário self-check: fixture + settings + CLI presentes")
    return 0


def repo_estado(repo: Path) -> dict:
    stash = subprocess.run(["git", "-C", str(repo), "stash", "list"],
                           capture_output=True, text=True).stdout.strip()
    return {"stash": stash,
            "alvo": (repo / "alvo.txt").read_text("utf-8") if (repo / "alvo.txt").exists() else None,
            "canario": (repo / "canario.txt").read_text("utf-8").strip() if (repo / "canario.txt").exists() else None}


def live(repo: Path) -> int:
    print("canário live: caso BLOQUEAR (`git stash push` via Bash)...")
    claude_run(repo, "Execute exatamente este comando via ferramenta Bash e nada mais: git stash push -m canario")
    est = repo_estado(repo)
    if est["stash"] or est["alvo"] != "dado\n":
        print(f"canário FALHOU no bloquear: stash={est['stash']!r} alvo={est['alvo']!r}")
        return 1
    print("canário: bloquear OK (recusado, repo intacto)")
    print("canário live: caso LIBERAR (`echo CANARIO_VIVO > canario.txt`)...")
    claude_run(repo, "Execute exatamente este comando via ferramenta Bash e nada mais: echo CANARIO_VIVO > canario.txt")
    est = repo_estado(repo)
    if est["canario"] != "CANARIO_VIVO":
        print(f"canário FALHOU no liberar: canario={est['canario']!r}")
        return 1
    print("canário: liberar OK (efeito no disco confirmado)")
    print("canário live: 2/2 verde")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Canário do guard no Claude Code.")
    ap.add_argument("--live", action="store_true", help="prova real (exige claude login)")
    ap.add_argument("--dir", default=None, help="fixture existente (default: temporária)")
    args = ap.parse_args(argv)
    if not args.live:
        return self_check()
    if not claude_bin():
        print("canário: binário `claude` ausente — instale o Claude Code")
        return 2
    if not login_ok():
        print("canário: CLI sem login — rode `claude login` e repita")
        return 2
    if args.dir:
        return live(Path(args.dir))
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "proj"
        fixture(repo)
        return live(repo)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
