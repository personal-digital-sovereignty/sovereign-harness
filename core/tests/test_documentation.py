"""Provas reais de preservação e fronteiras da migração documental."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("documentation", Path(__file__).parents[1] / "documentation.py")
docs = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(docs)


class Documentation(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "projeto com espaço"
        self.root.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        self.git("init", "-q")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], env=self.env,
                              check=True, capture_output=True)

    def put(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content.encode() if isinstance(content, str) else content)
        self.git("add", "--", name)

    def plan(self, moves):
        path = Path(self.tmp.name) / "plan.json"
        path.write_text(json.dumps({"version": 1, "moves": moves}))
        return path

    def test_move_preserves_binary_unicode_and_link_meaning(self):
        self.put("old/epic.md", "# Épico\n[decisão](adr/a.md#decisão)\n![evidência](prova.bin)\n")
        self.put("old/adr/a.md", "# Decisão\n[origem](../epic.md)\n")
        self.put("old/prova.bin", bytes(range(256)))
        self.put("AGENTS.md", "[épico](old/epic.md)\n")
        plan = self.plan({"old/epic.md": "docs/epics/epic.md", "old/adr/a.md": "docs/adr/a.md", "old/prova.bin": "docs/epics/prova.bin"})
        dry = docs.migrate(self.root, plan, False, [])
        self.assertTrue((self.root / "old/epic.md").exists())
        self.assertFalse((self.root / "docs").exists())
        result = docs.migrate(self.root, plan, True, [])
        self.assertEqual(result, dry)
        self.assertEqual((self.root / "docs/epics/prova.bin").read_bytes(), bytes(range(256)))
        self.assertIn("../adr/a.md#decisão", (self.root / "docs/epics/epic.md").read_text())
        self.assertEqual(docs.check(self.root, ["docs", "AGENTS.md"], []), [])
        (self.root / "docs/adr/a.md").unlink()
        self.assertTrue(docs.check(self.root, ["docs", "AGENTS.md"], []))

    def test_collision_refuses_before_any_write(self):
        self.put("old/a.md", "A")
        self.put("old/b.md", "B")
        self.put("docs/b.md", "trabalho existente")
        with self.assertRaisesRegex(ValueError, "já existe"):
            docs.migrate(self.root, self.plan({"old/a.md": "docs/a.md", "old/b.md": "docs/b.md"}), True, [])
        self.assertFalse((self.root / "docs/a.md").exists())
        self.assertEqual((self.root / "docs/b.md").read_text(), "trabalho existente")

    def test_symlink_parent_refused(self):
        self.put("old/a.md", "A")
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (self.root / "docs").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            docs.migrate(self.root, self.plan({"old/a.md": "docs/a.md"}), True, [])
        self.assertEqual(list(outside.iterdir()), [])

    def test_traversal_and_duplicate_destinations_refused(self):
        self.put("a.md", "A")
        self.put("b.md", "B")
        for moves in ({"a.md": "../escape.md"}, {"a.md": "docs/x.md", "b.md": "docs/x.md"}):
            with self.subTest(moves=moves), self.assertRaises(ValueError):
                docs.migrate(self.root, self.plan(moves), True, [])

    def test_absolute_alias_and_reference_link_rebased(self):
        self.put("old/a.md", "[b]: file:///previous/project/old/b.md#x\n")
        self.put("old/b.md", "B")
        docs.migrate(self.root, self.plan({"old/a.md": "docs/epics/a.md", "old/b.md": "docs/adr/b.md"}), True, ["/previous/project"])
        self.assertEqual((self.root / "docs/epics/a.md").read_text(), "[b]: ../adr/b.md#x\n")

    def test_canonical_resource_and_excluded_board_preserved(self):
        canonical = "[quadro](file:///previous/project/.agents/board.md)\n"
        self.put("old/a.md", canonical)
        self.put(".agents/board.md", "[doc](../old/a.md)\n")
        plan = self.plan({"old/a.md": "docs/a.md"})
        data = json.loads(plan.read_text())
        data["exclude"] = [".agents/board.md"]
        plan.write_text(json.dumps(data))
        docs.migrate(self.root, plan, True, ["/previous/project"])
        self.assertEqual((self.root / "docs/a.md").read_text(), canonical)
        self.assertEqual((self.root / ".agents/board.md").read_text(), "[doc](../old/a.md)\n")

    def test_nested_repository_is_not_migrated(self):
        self.put("old/a.md", "A")
        child = self.root / "member"
        child.mkdir()
        subprocess.run(["git", "init", "-q", str(child)], env=self.env, check=True)
        (child / "README.md").write_text("old/a.md")
        docs.migrate(self.root, self.plan({"old/a.md": "docs/a.md"}), True, [])
        self.assertEqual((child / "README.md").read_text(), "old/a.md")

    def test_link_checker_ignores_code_and_remote_but_finds_real_break(self):
        self.put("docs/a.md", "```md\n[exemplo](ausente.md)\n```\n`[literal](url)` e ``[outro](example)``\n[web](https://example.com)\n[quebrado](real.md)\n")
        failures = docs.check(self.root, ["docs"], [])
        self.assertEqual([(f["source"], f["target"]) for f in failures], [("docs/a.md", "docs/real.md")])


if __name__ == "__main__":
    unittest.main()
