"""Instalador do kit: a convenção `.agents/` (ADR-057 do projeto de origem) vira
verificação, não só texto. Roda o install.sh de verdade em diretórios descartáveis."""
from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
INSTALL = KIT / "install.sh"


def instalar(alvo: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["bash", str(INSTALL), str(alvo), *args], capture_output=True, text=True)


class Instalador(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.alvo = Path(self._tmp.name) / "proj"
        self.alvo.mkdir()
        subprocess.run(["git", "init", "-q", str(self.alvo)], check=True)

    def tearDown(self):
        self._tmp.cleanup()

    def test_padrao_agents(self):
        r = instalar(self.alvo)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        skills = sorted(p.parent.name for p in (self.alvo / ".agents" / "skills").glob("*/SKILL.md"))
        self.assertGreaterEqual(len(skills), 12)
        compat = self.alvo / ".claude" / "skills"
        self.assertTrue(compat.is_symlink())
        self.assertEqual(os.readlink(compat), "../.agents/skills")
        self.assertEqual(sorted(p.parent.name for p in compat.glob("*/SKILL.md")), skills)
        self.assertTrue((self.alvo / ".agents" / "rules" / "sovereign-10-guardrails.md").is_file())
        self.assertTrue((self.alvo / ".agents" / "workflows" / "quadro.md").is_file())
        self.assertFalse((self.alvo / ".agent").exists())

    def test_idempotente(self):
        self.assertEqual(instalar(self.alvo).returncode, 0)
        r = instalar(self.alvo)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("criados:    0", r.stdout)

    def test_claude_skills_diretorio_real_vira_conflito(self):
        (self.alvo / ".claude" / "skills" / "minha").mkdir(parents=True)
        r = instalar(self.alvo)
        self.assertEqual(r.returncode, 3, r.stdout)
        self.assertIn(".claude/skills (existe e não é symlink)", r.stdout)
        self.assertIn("mova as skills para .agents/skills", r.stdout)
        self.assertTrue((self.alvo / ".claude" / "skills" / "minha").is_dir())  # nada sobrescrito

    def test_sem_skills_preserva_as_do_projeto(self):
        propria = self.alvo / ".agents" / "skills" / "do-projeto"
        propria.mkdir(parents=True)
        (propria / "SKILL.md").write_text("---\nname: do-projeto\ndescription: x\n---\n")
        r = instalar(self.alvo, "--sem-skills")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertEqual([p.name for p in (self.alvo / ".agents" / "skills").iterdir()], ["do-projeto"])
        self.assertTrue((self.alvo / ".claude" / "skills").is_symlink())

    def test_sem_claude_nao_cria_symlink(self):
        r = instalar(self.alvo, "--agentes", "codex,opencode")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertFalse((self.alvo / ".claude" / "skills").exists())
        self.assertTrue((self.alvo / ".agents" / "skills").is_dir())


if __name__ == "__main__":
    unittest.main()
