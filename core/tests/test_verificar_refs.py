"""Verificador genérico de refs de docs: verde quando resolve, vermelho quando quebra."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
SCRIPT = KIT / "scripts" / "verificar_refs.py"


def rodar(docs: Path, raiz: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--docs", str(docs), "--raiz", str(raiz)],
        capture_output=True, text=True)


class VerificarRefs(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)

    def doc(self, nome: str, texto: str) -> Path:
        p = self.base / nome
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(texto, encoding="utf-8")
        return p

    def test_tudo_resolve(self):
        self.doc("docs/b.md", "# B\n")
        self.doc("docs/a.md", "# A\n[ver B](b.md)\nâncora [x](b.md#secao)\n`b.md`\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("refs em dia", r.stdout)

    def test_quebrado_reprova_e_nomeia_o_alvo(self):
        # Prova negativa: sem este teste o script seria decoração.
        self.doc("docs/a.md", "# A\n[perdido](sumido.md)\n`saiu/sub.md`\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("sumido.md", r.stdout)
        self.assertIn("saiu/sub.md", r.stdout)
        self.assertIn("docs/a.md:2", r.stdout)
        self.assertIn("docs/a.md:3", r.stdout)

    def test_alvo_com_barra_resolve_pela_raiz(self):
        self.doc("docs/guia/b.md", "# B\n")
        self.doc("docs/a.md", "# A\n[ver B](/docs/guia/b.md)\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_url_externa_e_ignorada(self):
        self.doc("docs/a.md", "# A\n[site](https://example.com/x.md)\n[mail](mailto:a@b.c)\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_placeholder_e_ignorado(self):
        self.doc("docs/a.md", "# A\n`.agents/skills/<nome>/SKILL.md`\n[tmpl](<arquivo>.md)\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_texto_de_link_nao_e_alvo(self):
        self.doc("docs/b.md", "# B\n")
        self.doc("docs/a.md", "# A\n[`b.md`](b.md)\n[`sumido.md`](b.md)\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_destino_de_link_quebrado_acusa(self):
        self.doc("docs/a.md", "# A\n[`b.md`](sumido.md)\n")
        r = rodar(self.base / "docs", self.base)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("sumido.md", r.stdout)

    def test_docs_inexistente_falha_alto(self):
        r = rodar(self.base / "nao-existe", self.base)
        self.assertEqual(r.returncode, 1)
        self.assertIn("inexistente", r.stdout)


if __name__ == "__main__":
    unittest.main()
