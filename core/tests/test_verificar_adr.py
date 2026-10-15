"""Validador de índice/identidade de ADR: duplicado reprova nomeando os arquivos."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
SCRIPT = KIT / "scripts" / "verificar_adr.py"


def rodar(adr: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--adr-dir", str(adr), *extra],
        capture_output=True, text=True)


class VerificarAdr(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.adr = Path(tmp.name) / "adr"
        self.adr.mkdir()

    def adr_file(self, nome: str, texto: str = "# x\n") -> Path:
        p = self.adr / nome
        p.write_text(texto, encoding="utf-8")
        return p

    def indice(self, texto: str) -> Path:
        return self.adr_file("ADR-INDEX.md", texto)

    def test_tudo_em_dia(self):
        self.adr_file("ADR-001-contexto.md")
        self.adr_file("ADR-002-outra.md")
        self.indice("# Índice\nADR-001-contexto.md\nADR-002-outra.md\nPróximo número livre: ADR-003.\n")
        r = rodar(self.adr)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("adr em dia", r.stdout)

    def test_duplicado_reprova_nomeando_os_dois(self):
        # Prova negativa (GAP-20261015-035 do projeto de origem: duas ADR-001).
        self.adr_file("ADR-001-contexto.md")
        self.adr_file("ADR-001-outro-slug.md")
        self.indice("# Índice\nADR-001-contexto.md\nADR-001-outro-slug.md\nPróximo número livre: ADR-002.\n")
        r = rodar(self.adr)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("duplicado", r.stdout)
        self.assertIn("ADR-001-contexto.md", r.stdout)
        self.assertIn("ADR-001-outro-slug.md", r.stdout)

    def test_sem_linha_no_indice_reprova(self):
        self.adr_file("ADR-007-orfao.md")
        self.indice("# Índice\nPróximo número livre: ADR-008.\n")
        r = rodar(self.adr)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("ADR-007-orfao.md", r.stdout)

    def test_proximo_livre_errado_reprova(self):
        self.adr_file("ADR-003-x.md")
        self.indice("# Índice\nADR-003-x.md\nPróximo número livre: ADR-009.\n")
        r = rodar(self.adr)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("ADR-009", r.stdout)
        self.assertIn("ADR-003", r.stdout)

    def test_template_e_indice_nao_sao_adrs(self):
        self.adr_file("TEMPLATE.md")
        self.indice("# Índice\nPróximo número livre: ADR-001.\n")
        r = rodar(self.adr)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_indice_ausente_falha_alto(self):
        self.adr_file("ADR-001-x.md")
        r = rodar(self.adr)
        self.assertEqual(r.returncode, 1)
        self.assertIn("inexistente", r.stdout)

    def test_adr_dir_ausente_falha_alto(self):
        r = rodar(self.adr / "nao-existe")
        self.assertEqual(r.returncode, 1)
        self.assertIn("inexistente", r.stdout)


if __name__ == "__main__":
    unittest.main()
