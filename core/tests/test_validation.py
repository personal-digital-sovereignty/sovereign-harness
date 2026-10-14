"""Gates contra processos e repositórios reais; nenhuma stack/forge simulada."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).parents[1] / "validation.py"


class Validation(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "project"
        self.root.mkdir()
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.invalid",
                        GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.invalid")
        self.git("init", "-q", "-b", "trunk")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args, root=None):
        return subprocess.run(["git", "-C", str(root or self.root), *args], env=self.env,
                              capture_output=True, text=True, check=True).stdout.strip()

    def config(self, topology="repository", members="[]", gate_cwd=".", exit_code=0):
        (self.root / ".harness.toml").write_text(
            f'[project]\ntopology="{topology}"\nmembers={members}\n'
            f'[validation]\nconfigured=true\n[[validation.gates]]\nid="real-process"\n'
            f'argv=["{sys.executable}", "-c", "from pathlib import Path; Path(\'evidence.txt\').write_text(\'executed\'); raise SystemExit({exit_code})"]\ncwd="{gate_cwd}"\n')

    def run_gate(self, phase="check", stdin=""):
        return subprocess.run([sys.executable, str(RUNNER), "--root", str(self.root), phase],
                              input=stdin, capture_output=True, text=True, env=self.env)

    def test_repository_without_remote_or_main_executes_and_failure_propagates(self):
        self.config()
        self.assertEqual(self.run_gate().returncode, 0)
        self.assertEqual((self.root / "evidence.txt").read_text(), "executed")
        self.config(exit_code=7)
        result = self.run_gate()
        self.assertEqual(result.returncode, 1)
        self.assertIn("exit 7", result.stderr)

    def test_monorepo_uses_declared_package_cwd(self):
        package = self.root / "packages" / "component"
        package.mkdir(parents=True)
        self.config("monorepo", gate_cwd="packages/component")
        self.assertEqual(self.run_gate().returncode, 0)
        self.assertTrue((package / "evidence.txt").exists())
        self.assertFalse((self.root / "evidence.txt").exists())

    def test_meta_repository_requires_and_executes_real_member(self):
        member = self.root / "member"
        member.mkdir()
        self.git("init", "-q", "-b", "develop", root=member)
        self.config("meta-repository", '["member"]', "member")
        self.assertEqual(self.run_gate().returncode, 0)
        self.assertTrue((member / "evidence.txt").exists())
        self.config("meta-repository")
        self.assertEqual(self.run_gate().returncode, 2)

    def test_unconfigured_and_outside_cwd_refuse(self):
        (self.root / ".harness.toml").write_text('[validation]\nconfigured=false\n')
        self.assertEqual(self.run_gate().returncode, 2)
        self.config(gate_cwd="..")
        self.assertEqual(self.run_gate().returncode, 2)
        self.assertFalse((Path(self.tmp.name) / "evidence.txt").exists())

    def test_push_only_validates_clean_matching_head(self):
        self.config()
        self.git("add", ".harness.toml")
        self.git("commit", "-qm", "fixture")
        head = self.git("rev-parse", "HEAD")
        zero = "0" * 40
        refs = f"refs/heads/trunk {head} refs/heads/trunk {zero}\n"
        self.assertEqual(self.run_gate("pre-push", refs).returncode, 0)
        wrong = f"refs/heads/other {'1'*40} refs/heads/other {zero}\n"
        self.assertEqual(self.run_gate("pre-push", refs + wrong).returncode, 2)
        (self.root / ".harness.toml").write_text((self.root / ".harness.toml").read_text() + '\n# dirty\n')
        self.assertEqual(self.run_gate("pre-push", refs).returncode, 2)


if __name__ == "__main__":
    unittest.main()
