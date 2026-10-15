"""Instalador do kit: a convenção `.agents/` (ADR-057 do projeto de origem) vira
verificação, não só texto. Roda o install.sh de verdade em diretórios descartáveis."""
from __future__ import annotations

import os
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
INSTALL = KIT / "install.sh"


def instalar(alvo: Path, *args: str) -> subprocess.CompletedProcess:
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    return subprocess.run(["bash", str(INSTALL), str(alvo), *args], env=env, capture_output=True, text=True)


class Instalador(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.alvo = Path(self._tmp.name) / "proj"
        self.alvo.mkdir()
        env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        subprocess.run(["git", "init", "-q", str(self.alvo)], check=True, env=env)

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
        for name in ("PENDING.md", "ROADMAP.md", "CONCLUSION.md", "epics/README.md", "gaps/README.md", "templates/EPIC.md"):
            self.assertTrue((self.alvo / "docs" / name).is_file(), name)
        self.assertFalse((self.alvo / "project_docs").exists())
        self.assertTrue((self.alvo / ".harness/validation.py").is_file())
        self.assertFalse((self.alvo / "scripts/merge_gate.sh").exists())
        self.assertIn("validation.py", (self.alvo / ".githooks/pre-push").read_text())

    def test_perfil_github_e_opt_in(self):
        result = instalar(self.alvo, "--git-profile", "github-rust-node")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.alvo / "scripts/merge_gate.sh").is_file())
        self.assertTrue((self.alvo / ".agents/quadro.sh").is_file())

    def test_hook_codex_preserva_caminho_com_metacaracteres(self):
        target = Path(self._tmp.name) / "quote' space $(touch INJECTED) `touch INJECTED`"
        target.mkdir()
        result = instalar(target, "--agentes", "codex")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads((target / ".codex/hooks.json").read_text())
        command = data["hooks"]["SessionStart"][0]["hooks"][0]["command"]
        result = subprocess.run(["sh", "-c", command], cwd=target, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((target / "INJECTED").exists())

    def test_pre_push_instalado_recusa_perfil_incompleto(self):
        self.assertEqual(instalar(self.alvo).returncode, 0)
        result = subprocess.run([str(self.alvo / ".githooks/pre-push")], cwd=self.alvo,
                                input=f"refs/heads/trunk {'1'*40} refs/heads/trunk {'0'*40}\n",
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("configured=true", result.stderr)

    def test_perfil_invalido_recusa_sem_instalar(self):
        profile = Path(self._tmp.name) / "invalid.toml"
        profile.write_text("[harness\n")
        result = instalar(self.alvo, "--perfil", str(profile))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.alvo / ".harness").exists())

    def test_agente_desconhecido_recusa_sem_instalar(self):
        result = instalar(self.alvo, "--agentes", "inexistente")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.alvo / ".harness").exists())

    def test_pasta_symlink_nao_escreve_fora(self):
        outside = Path(self._tmp.name) / "outside"
        outside.mkdir()
        (self.alvo / ".harness").symlink_to(outside, target_is_directory=True)
        result = instalar(self.alvo)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_verificar_nao_escreve_no_alvo(self):
        result = instalar(self.alvo, "--verificar")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([p.name for p in self.alvo.iterdir()], [".git"])

    def test_documentacao_instalada_tem_links_validos(self):
        self.assertEqual(instalar(self.alvo).returncode, 0)
        result = subprocess.run(["python3", str(self.alvo / ".harness/documentation.py"), "check"],
                                cwd=self.alvo, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

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

    def test_docs_dir_customizado_e_refs_verdes(self):
        r = instalar(self.alvo, "--docs-dir", "engineering")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((self.alvo / "engineering" / "PENDING.md").is_file())
        self.assertTrue((self.alvo / "engineering" / "ROADMAP.md").is_file())
        self.assertTrue((self.alvo / "engineering" / "adr" / "ADR-INDEX.md").is_file())
        self.assertFalse((self.alvo / "docs").exists())
        agents = (self.alvo / "AGENTS.md").read_text("utf-8")
        self.assertIn("engineering/PENDING.md", agents)
        self.assertIn("engineering/CONCLUSION.md", agents)
        self.assertNotIn("docs/", agents)
        self.assertIn("<nome do projeto>", agents)  # sem --project-name, placeholder fica
        self.assertIn("refs em engineering: em dia", r.stdout)

    def test_docs_dir_padrao_e_refs_verdes(self):
        r = instalar(self.alvo)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((self.alvo / "docs" / "PENDING.md").is_file())
        self.assertIn("refs em docs: em dia", r.stdout)

    def test_docs_dir_invalido_falha_alto(self):
        for ruim in ("/absoluto", "../fora", ""):
            r = instalar(self.alvo, "--docs-dir", ruim)
            self.assertEqual(r.returncode, 1, ruim + r.stdout + r.stderr)
            self.assertIn("--docs-dir", r.stdout + r.stderr)

    def test_project_name_preenche_titulo(self):
        r = instalar(self.alvo, "--project-name", "Meu Projeto")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        primeira = (self.alvo / "AGENTS.md").read_text("utf-8").splitlines()[0]
        self.assertEqual(primeira, "# Instruções para agentes de IA — Meu Projeto")

    def test_idempotente_com_flags(self):
        self.assertEqual(instalar(self.alvo, "--docs-dir", "engineering").returncode, 0)
        r = instalar(self.alvo, "--docs-dir", "engineering")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("criados:    0", r.stdout)
        self.assertIn("refs em engineering: em dia", r.stdout)


if __name__ == "__main__":
    unittest.main()
