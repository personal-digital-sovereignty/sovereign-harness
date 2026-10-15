import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("github_checks", Path(__file__).parents[1] / "github_checks.py")
checks = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checks)


class GitHubChecks(unittest.TestCase):
    def test_verde_com_checks_opcionais_pulados(self):
        self.assertEqual(checks.validate(0, '[{"bucket":"pass"},{"bucket":"skipping"}]'), 2)

    def test_erro_nao_vira_lista_vazia(self):
        for code in (1, 4, 8, 127):
            with self.subTest(code=code), self.assertRaises(ValueError):
                checks.validate(code, '[]')

    def test_ausencia_ou_resposta_invalida_recusa(self):
        for payload in ('', 'null', '{}', '[]', '[1]', 'invalid', '[{"bucket":"skipping"}]'):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                checks.validate(0, payload)

    def test_nao_verde_recusa_mesmo_com_exit_zero(self):
        for bucket in ('fail', 'pending', 'cancel', 'unknown'):
            with self.subTest(bucket=bucket), self.assertRaises(ValueError):
                checks.validate(0, '[{"bucket":"' + bucket + '"}]')
