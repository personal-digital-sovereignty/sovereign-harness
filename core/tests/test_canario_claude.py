"""Canário do Claude Code: self-checks sem login; live só com `claude login`."""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

KIT = Path(__file__).resolve().parents[2]
SCRIPT = KIT / "scripts" / "canario_claude.py"


def carregar():
    spec = importlib.util.spec_from_file_location("canario_claude", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod


class CanarioClaude(unittest.TestCase):
    def test_self_check_sem_login(self):
        # Roda no CI: não exige CLI logado, só binário presente ou ausente digno.
        r = subprocess.run([sys.executable, str(SCRIPT)],
                           capture_output=True, text=True)
        self.assertIn(r.returncode, (0, 1), r.stdout + r.stderr)

    def test_fixture_gera_settings_apontando_para_o_guard(self):
        mod = carregar()
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "proj"
            mod.fixture(repo)
            doc = json.loads((repo / ".claude" / "settings.json").read_text("utf-8"))
            hook = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
            self.assertIn("harness_guard.py\" hook", hook)
            self.assertIn(str(KIT / "core" / "harness_guard.py"), hook)
            self.assertTrue((repo / "alvo.txt").is_file())

    def test_login_ok_distinguindo_respostas_reais(self):
        mod = carregar()
        with mock.patch.object(mod, "claude_run", return_value={"is_error": False, "result": "OK"}):
            self.assertTrue(mod.login_ok())
        with mock.patch.object(mod, "claude_run",
                               return_value={"is_error": True,
                                             "result": "Failed to authenticate: OAuth session expired"}):
            self.assertFalse(mod.login_ok())
        with mock.patch.object(mod, "claude_run", side_effect=RuntimeError("sem JSON")):
            self.assertFalse(mod.login_ok())

    def test_live_sem_login_falha_alto_pedindo_login(self):
        mod = carregar()
        with mock.patch.object(mod, "claude_bin", return_value="/usr/bin/claude"), \
             mock.patch.object(mod, "login_ok", return_value=False):
            rc = mod.main(["--live"])
            self.assertEqual(rc, 2)

    def test_live_vereditos_por_estado_do_disco(self):
        mod = carregar()
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "proj"
            mod.fixture(repo)
            # bloquear: nada muda no disco
            subprocess.run(["git", "-C", str(repo), "stash", "list"], check=True,
                           capture_output=True)
            est = mod.repo_estado(repo)
            self.assertEqual(est["stash"], "")
            self.assertEqual(est["alvo"], "dado\n")
            self.assertIsNone(est["canario"])
            # liberar: efeito escrito
            (repo / "canario.txt").write_text("CANARIO_VIVO\n", encoding="utf-8")
            self.assertEqual(mod.repo_estado(repo)["canario"], "CANARIO_VIVO")


if __name__ == "__main__":
    unittest.main()
