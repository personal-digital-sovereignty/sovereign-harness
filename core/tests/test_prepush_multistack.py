"""Pre-push legado multi-stack: cada stack detectada roda seus gates.

Repos git reais descartáveis + ferramentas reais (cargo, npm, ruff, pytest).
Scanners (gitleaks/trivy/semgrep) pulados por HARNESS_SKIP explícito: o trivy
precisa de rede para o DB e o objeto aqui é o despacho por stack, não eles.
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
PREPUSH = KIT / "templates" / "git" / "pre-push"
ZERO = "0" * 40
SKIP_SCANNERS = "gitleaks,trivy,semgrep"


def git(repo: Path, *args: str) -> str:
    r = subprocess.run(["git", "-C", str(repo), *args],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()


class MultiStack(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)
        self.origin = self.base / "origin.git"
        subprocess.run(["git", "init", "--bare", "-q", str(self.origin)], check=True)
        self.repo = self.base / "proj"
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.repo)], check=True)
        git(self.repo, "config", "user.email", "t@t")
        git(self.repo, "config", "user.name", "t")

    def commit(self, msg: str) -> str:
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-qm", msg)
        return git(self.repo, "rev-parse", "HEAD")

    def push_base(self):
        git(self.repo, "remote", "add", "origin", str(self.origin))
        git(self.repo, "push", "-q", "origin", "HEAD:main")

    def prepush(self, new: str) -> subprocess.CompletedProcess[str]:
        env = dict(os.environ, HARNESS_SKIP=SKIP_SCANNERS)
        entrada = f"refs/heads/main {new} refs/heads/main {ZERO}\n"
        return subprocess.run(["bash", str(PREPUSH), "origin", str(self.origin)],
                              input=entrada, capture_output=True, text=True,
                              cwd=self.repo, env=env)

    def rust_lib(self):
        (self.repo / "Cargo.toml").write_text(
            '[package]\nname = "mini"\nversion = "0.1.0"\nedition = "2021"\n')
        src = self.repo / "src"
        src.mkdir(exist_ok=True)
        (src / "lib.rs").write_text(
            "pub fn soma(a: i32, b: i32) -> i32 {\n    a + b\n}\n\n"
            "#[cfg(test)]\nmod tests {\n    use super::*;\n\n"
            "    #[test]\n    fn soma_dois() {\n        assert_eq!(soma(1, 2), 3);\n    }\n}\n")

    def node_pkg(self):
        (self.repo / "package.json").write_text(
            '{"name": "mini", "scripts": {"check": "exit 0", "test": "exit 0"}}\n')
        bin_dir = self.repo / "node_modules" / ".bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        prettier = bin_dir / "prettier"
        # Dublê que registra o que recebeu: prova o despacho + escopo por arquivo.
        prettier.write_text('#!/usr/bin/env bash\necho "$@" >> "$(dirname "$0")/calls.log"\n')
        prettier.chmod(0o755)
        (self.repo / "index.ts").write_text("export const x: number = 1;\n")

    def python_pkg(self):
        (self.repo / "pyproject.toml").write_text('[project]\nname = "mini"\nversion = "0.1.0"\n')
        (self.repo / "calc.py").write_text('def soma(a, b):\n    return a + b\n')
        (self.repo / "test_calc.py").write_text(
            "from calc import soma\n\n\ndef test_soma():\n    assert soma(1, 2) == 3\n")

    def test_multi_stack_roda_os_gates_das_tres(self):
        (self.repo / "README.md").write_text("# mini\n")
        self.commit("base")
        self.push_base()
        self.rust_lib()
        self.node_pkg()
        self.python_pkg()
        new = self.commit("tres stacks")
        r = self.prepush(new)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        # types: rust + node. test e lint: uma vez por stack.
        self.assertEqual(r.stdout.count("✅ types"), 2, r.stdout)
        self.assertEqual(r.stdout.count("✅ test"), 3, r.stdout)
        self.assertEqual(r.stdout.count("✅ lint"), 3, r.stdout)
        chamadas = (self.repo / "node_modules" / ".bin" / "calls.log").read_text()
        self.assertIn("index.ts", chamadas, chamadas)

    def test_python_sozinho_nao_chama_rust_nem_node(self):
        (self.repo / "README.md").write_text("# mini\n")
        self.commit("base")
        self.push_base()
        self.python_pkg()
        new = self.commit("só python")
        r = self.prepush(new)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(r.stdout.count("✅ test"), 1, r.stdout)
        self.assertEqual(r.stdout.count("✅ lint"), 1, r.stdout)
        self.assertNotIn("clippy", r.stdout)
        self.assertNotIn("npm", r.stdout)

    def test_lint_python_sujo_reprova(self):
        # Prova negativa: o gate morde de verdade (ruff real).
        (self.repo / "pyproject.toml").write_text('[project]\nname = "mini"\n')
        self.commit("base")
        self.push_base()
        (self.repo / "sujo.py").write_text("import os\n\n\ndef f():\n    return 1\n")
        (self.repo / "test_sujo.py").write_text("def test_ok():\n    assert True\n")
        new = self.commit("sujo")
        r = self.prepush(new)
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertIn("❌ lint", r.stdout)

    def test_teste_python_quebrado_reprova(self):
        (self.repo / "pyproject.toml").write_text('[project]\nname = "mini"\n')
        self.commit("base")
        self.push_base()
        (self.repo / "ok.py").write_text("X = 1\n")
        (self.repo / "test_ok.py").write_text("def test_falha():\n    assert False\n")
        new = self.commit("quebrado")
        r = self.prepush(new)
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertIn("❌ test", r.stdout)


if __name__ == "__main__":
    unittest.main()
