"""Integridade do kit: cópias dos plugins em dia com a fonte, manifestos válidos,
skills com frontmatter coerente. Roda junto da suíte do guard."""
from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]


class Kit(unittest.TestCase):
    def test_copias_em_dia_com_a_fonte(self):
        r = subprocess.run([sys.executable, str(KIT / "scripts" / "sincronizar.py"), "--verificar"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_manifestos_json_validos(self):
        arquivos = [p for p in KIT.rglob("*.json") if "node_modules" not in p.parts]
        self.assertGreaterEqual(len(arquivos), 7)
        for p in arquivos:
            with self.subTest(p=p.relative_to(KIT)):
                json.loads(p.read_text("utf-8"))

    def test_skills_frontmatter(self):
        skills = sorted((KIT / "skills").glob("*/SKILL.md"))
        self.assertGreaterEqual(len(skills), 12)
        for s in skills:
            with self.subTest(skill=s.parent.name):
                m = re.match(r"^---\nname: (.+)\ndescription: (.+)\n---\n", s.read_text("utf-8"))
                self.assertIsNotNone(m, "frontmatter ausente ou fora do formato name/description")
                self.assertEqual(m.group(1), s.parent.name)
                self.assertRegex(m.group(1), r"^[a-z0-9]+(-[a-z0-9]+)*$")
                self.assertLessEqual(len(m.group(2)), 1024)

    def test_versoes_dos_manifestos_iguais_a_do_guard(self):
        m = re.search(r'^VERSAO = "([^"]+)"$', (KIT / "core" / "harness_guard.py").read_text("utf-8"), re.M)
        self.assertIsNotNone(m, "VERSAO ausente no guard")
        esperado = m.group(1)
        alvos = {
            KIT / ".claude-plugin/marketplace.json": ("metadata", "version"),
            KIT / "plugins/claude-code/sovereign-harness-guard/.claude-plugin/plugin.json": ("version",),
            KIT / "plugins/claude-code/sovereign-harness-metodo/.claude-plugin/plugin.json": ("version",),
            KIT / "plugins/codex/sovereign-harness/.codex-plugin/plugin.json": ("version",),
        }
        for p, caminho in alvos.items():
            with self.subTest(manifesto=str(p.relative_to(KIT))):
                doc = json.loads(p.read_text("utf-8"))
                for chave in caminho:
                    doc = doc[chave]
                self.assertEqual(doc, esperado,
                                 f"manifesto em {doc}, guard em {esperado} — bump incompleto?")

    def test_doc_governance_cobre_o_ciclo(self):
        texto = (KIT / "skills" / "doc-governance" / "SKILL.md").read_text("utf-8")
        for marcador in ("epics", "gaps", "insights", "ADR", "verificar_refs",
                         "PENDING", "CONCLUSION", "ADR-INDEX", "_legacy"):
            self.assertIn(marcador, texto, f"skill doc-governance não fala de {marcador}")

    def test_comandos_tem_descricao(self):
        for c in sorted((KIT / "commands").glob("*.md")):
            with self.subTest(comando=c.name):
                self.assertRegex(c.read_text("utf-8"), r"^---\ndescription: .+\n")

    def test_regras_antigravity_always_on(self):
        for r in sorted((KIT / "plugins" / "antigravity" / "rules").glob("*.md")):
            with self.subTest(regra=r.name):
                self.assertTrue(r.read_text("utf-8").startswith("---\ntrigger: always_on\n---\n"))


if __name__ == "__main__":
    unittest.main()
