"""Testes do harness_guard — cada regra provada nos dois sentidos.

Um verificador que nunca reprova não vale nada: para cada regra há o caso do
incidente (tem de BLOQUEAR), o caso legítimo vizinho (tem de LIBERAR) e o escape
nomeado. Os repositórios são reais e descartáveis; nada toca o repositório de
quem roda o teste (GIT_DIR e config global isolados).

    python3 -m unittest discover -s <kit>/core/tests -v
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

GUARD = Path(__file__).resolve().parents[1] / "harness_guard.py"


class Base(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.raiz = Path(cls.tmp.name)
        gcfg = cls.raiz / "gitconfig"
        gcfg.write_text("")
        cls.env = {k: v for k, v in os.environ.items()
                   if k not in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "HARNESS_CONFIG", "HARNESS_SKIP",
                                "SOVEREIGN_SKIP_GATES")}
        cls.env.update({
            "GIT_CONFIG_GLOBAL": str(gcfg), "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "teste", "GIT_AUTHOR_EMAIL": "teste@exemplo.invalid",
            "GIT_COMMITTER_NAME": "teste", "GIT_COMMITTER_EMAIL": "teste@exemplo.invalid",
            "XDG_STATE_HOME": str(cls.raiz / "state"),
        })
        # repositório principal em `main`, com remote e merge gate
        cls.repo = cls.raiz / "repo"
        cls._git(cls.raiz, "init", "-q", "-b", "main", str(cls.repo))
        (cls.repo / "scripts").mkdir()
        (cls.repo / "scripts" / "merge_gate.sh").write_text("#!/bin/sh\n")
        (cls.repo / ".agents").mkdir()
        (cls.repo / ".agents" / "agents_work.md").write_text("# Quadro\n\n## 🔴 Em andamento\n\n### a/b — x\n\n## Fim\n")
        (cls.repo / "a.txt").write_text("a\n")
        cls._git(cls.repo, "add", "a.txt", "scripts", ".agents")
        cls._git(cls.repo, "commit", "-qm", "base")
        cls._git(cls.repo, "remote", "add", "origin", "https://exemplo.invalid/repo.git")
        # branch de trabalho num worktree vinculado, com node_modules symlinkado
        (cls.repo / "node_modules" / "pacote").mkdir(parents=True)
        cls.wt = cls.raiz / "wt"
        cls._git(cls.repo, "worktree", "add", "-q", "-b", "agente/tarefa", str(cls.wt), "main")
        os.symlink(cls.repo / "node_modules", cls.wt / "node_modules")
        # config do harness (perfil de teste)
        cls.cfg = cls.raiz / "harness.toml"
        cls.cfg.write_text(
            '[harness]\nescape_env = "SOVEREIGN_SKIP_GATES"\n'
            f'[quadro]\ncanonico = "{cls.repo}/.agents/agents_work.md"\nrelativo = ".agents/agents_work.md"\n'
            f'ler = "cat {cls.repo}/.agents/agents_work.md"\n'
        )
        cls.env["HARNESS_CONFIG"] = str(cls.cfg)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    @classmethod
    def _git(cls, cwd, *args):
        subprocess.run(["git", "-C", str(cwd), *args], check=True, env=cls.env, capture_output=True)

    def checar(self, cmd=None, cwd=None, arquivo=None, acao=None, extra_env=None):
        argv = [sys.executable, str(GUARD), "checar", "--cwd", str(cwd or self.wt)]
        if cmd is not None:
            argv += ["--cmd", cmd]
        if arquivo is not None:
            argv += ["--arquivo", str(arquivo)]
        if acao:
            argv += ["--acao", acao]
        env = {**self.env, **(extra_env or {})}
        r = subprocess.run(argv, capture_output=True, text=True, env=env, check=True)
        return json.loads(r.stdout)

    def bloqueia(self, regra, **kw):
        res = self.checar(**kw)
        self.assertEqual(res["decisao"], "bloquear", f"esperava bloquear por {regra}: {res}")
        self.assertIn(regra, [b["regra"] for b in res["bloqueios"]])
        return res

    def libera(self, **kw):
        res = self.checar(**kw)
        self.assertNotEqual(res["decisao"], "bloquear", f"esperava liberar: {res}")
        return res


class Regras(Base):
    # add-tudo -------------------------------------------------------------
    def test_add_tudo(self):
        for cmd in ("git add -A", "git add .", "git add --all", "rtk git add -A", "git -C . add :/", "git commit -am x",
                    "cd sub && git add .", "git add -u", "git add -A .agents", "git add 'src/*.rs'"):
            self.bloqueia("add-tudo", cmd=cmd)
        self.libera(cmd="git add a.txt docs/b.md")
        self.libera(cmd="git add -A src/api.rs CHANGELOG.md")  # -A com caminhos nominais
        (self.wt / "novo" / "sub").mkdir(parents=True, exist_ok=True)
        (self.wt / "novo" / "sub" / "x.md").write_text("x\n")
        self.libera(cmd="git add novo")  # diretório inteiramente novo: só tem o que você criou
        self.bloqueia("add-tudo", cmd="git add .agents")  # diretório com arquivo rastreado
        self.libera(cmd='git commit -m "explica por que git add -A é proibido"')
        self.libera(cmd="git commit -F - <<'MSG'\nproíbe git add -A e [skip ci] no texto\nMSG")

    # no-verify ------------------------------------------------------------
    def test_no_verify(self):
        self.bloqueia("no-verify", cmd="git push --no-verify origin x")
        self.bloqueia("no-verify", cmd="git commit -n -m msg")
        self.libera(cmd="git push -n origin x")  # -n do push é dry-run
        self.libera(cmd='git commit -m "-nada de mais"')

    # hooks-off ------------------------------------------------------------
    def test_hooks_off(self):
        self.bloqueia("hooks-off", cmd="git -c core.hooksPath=/dev/null merge --no-ff x")
        self.bloqueia("hooks-off", cmd="git config core.hooksPath /dev/null")
        self.bloqueia("hooks-off", cmd="git config --unset core.hooksPath")
        self.libera(cmd="git config core.hooksPath .githooks")

    # skip-ci --------------------------------------------------------------
    def test_skip_ci(self):
        self.bloqueia("skip-ci", cmd='git commit -m "fix: x [skip ci]"')
        self.bloqueia("skip-ci", cmd="git commit -qm 'docs [ci skip]'")
        self.libera(cmd='git commit -m "fix: x"')

    # pkill-f --------------------------------------------------------------
    def test_pkill(self):
        self.bloqueia("pkill-f", cmd="pkill -f sovereign-daemon")
        self.libera(cmd="kill 12345")
        self.libera(cmd="pkill -x sovereign-daemon")

    # stash-nu -------------------------------------------------------------
    def test_stash(self):
        for cmd in ("git stash", "git stash pop", "git stash -u", "git stash apply", "git stash clear", "git stash save x"):
            self.bloqueia("stash-nu", cmd=cmd)
        for cmd in ("git stash push -u -m tag-123", "git stash list", "git stash apply 1a2b3c4d", "git stash drop stash@{2}"):
            self.libera(cmd=cmd)

    # sudo -----------------------------------------------------------------
    def test_sudo(self):
        self.bloqueia("sudo", cmd="sudo apt install jq")
        self.bloqueia("sudo", cmd="FOO=1 sudo -n true")
        self.libera(cmd="echo 'sudo apt install jq'")

    # segredo-env ----------------------------------------------------------
    def test_segredo(self):
        self.bloqueia("segredo-env", cmd="cat .env")
        self.bloqueia("segredo-env", cmd="grep KEY /x/.env.local")
        self.bloqueia("segredo-env", arquivo="/x/.env", acao="ler")
        self.libera(cmd="grep -c '^OPENAI_API_KEY=' .env")
        self.libera(cmd="cut -d= -f1 .env")
        self.libera(cmd="cat .env.example")
        self.libera(arquivo="/x/.env.example", acao="ler")

    # commit-protegida -----------------------------------------------------
    def test_commit_protegida(self):
        self.bloqueia("commit-protegida", cmd="git commit -m x", cwd=self.repo)
        self.bloqueia("commit-protegida", cmd=f"git -C {self.repo} commit -m x")
        self.libera(cmd="git commit -m x")  # o worktree está em agente/tarefa

    # worktree-main-local --------------------------------------------------
    def test_worktree(self):
        self.bloqueia("worktree-main-local", cmd="git worktree add -b a/b ../x main", cwd=self.repo)
        self.bloqueia("worktree-main-local", cmd="git worktree add -b a/b ../x", cwd=self.repo)
        self.libera(cmd="git worktree add -b a/b ../x origin/main", cwd=self.repo)
        sem_remote = self.raiz / "sem-remote"
        self._git(self.raiz, "init", "-q", "-b", "main", str(sem_remote))
        self.libera(cmd="git worktree add ../y main", cwd=sem_remote)  # sem remote, o main local é a verdade

    # rm-symlink -----------------------------------------------------------
    def test_rm_symlink(self):
        self.bloqueia("rm-symlink", cmd="rm -rf node_modules/pacote")
        self.bloqueia("rm-symlink", cmd=f"rm -f {self.wt}/node_modules/pacote")
        self.libera(cmd="rm -f node_modules")  # remove só o link
        self.libera(cmd="rm -f a.txt")
        self.libera(cmd="rm -rf /tmp/qualquer-coisa")  # fora da árvore textualmente

    # npm-worktree ---------------------------------------------------------
    def test_npm_worktree(self):
        self.bloqueia("npm-worktree", cmd="npm install")
        self.bloqueia("npm-worktree", cmd="npm update vite")
        self.libera(cmd="npm run check")
        self.libera(cmd="npm install", cwd=self.repo)  # principal: node_modules é diretório real

    # merge-direto ---------------------------------------------------------
    def test_merge_direto(self):
        self.bloqueia("merge-direto", cmd="gh pr merge 42 --squash")
        self.libera(cmd="scripts/merge_gate.sh 42")
        self.libera(cmd="gh pr merge 42", cwd=self.raiz)  # fora de repo com merge gate

    # quadro-copia ---------------------------------------------------------
    def test_quadro(self):
        copia = self.wt / ".agents" / "agents_work.md"
        self.bloqueia("quadro-copia", arquivo=copia, acao="editar")
        self.bloqueia("quadro-copia", cmd=f"echo x >> {copia}")
        self.bloqueia("quadro-copia", cmd=f"sed -i 's/a/b/' {copia}")
        self.libera(arquivo=self.repo / ".agents" / "agents_work.md", acao="editar")
        self.libera(arquivo=self.wt / "outro.md", acao="editar")

    # gitconfig-global -----------------------------------------------------
    def test_gitconfig(self):
        self.bloqueia("gitconfig-global", cmd='git config --global user.email "x@y"')
        self.bloqueia("gitconfig-global", cmd="gh auth setup-git")
        self.libera(cmd="git config --global user.email")  # leitura

    # descarte-amplo / descarte-arquivo ------------------------------------
    def _repo_novo(self, nome):
        r = self.raiz / nome
        self._git(self.raiz, "init", "-q", "-b", "trabalho", str(r))
        (r / "a.txt").write_text("a\n")
        self._git(r, "add", "a.txt")
        self._git(r, "commit", "-qm", "base")
        return r

    def test_descarte_amplo_so_com_algo_a_perder(self):
        r = self._repo_novo("descarte-amplo")
        self.libera(cmd="git reset --hard", cwd=r)       # árvore limpa: nada a perder
        self.libera(cmd="git clean -fd", cwd=r)          # nada não rastreado
        (r / "a.txt").write_text("mudou\n")
        self.bloqueia("descarte-amplo", cmd="git reset --hard", cwd=r)
        self.bloqueia("descarte-amplo", cmd="git checkout .", cwd=r)
        (r / "novo.txt").write_text("x\n")
        self.bloqueia("descarte-amplo", cmd="git clean -fd", cwd=r)
        self.libera(cmd="git clean -n", cwd=r)
        self.libera(cmd="git reset HEAD~1", cwd=r)

    def test_descarte_arquivo_avisa_e_pode_ser_promovido(self):
        r = self._repo_novo("descarte-arquivo")
        self.libera(cmd="git checkout -- a.txt", cwd=r)  # sem mudança: nada a perder
        (r / "a.txt").write_text("mudou\n")
        res = self.checar(cmd="git checkout -- a.txt", cwd=r)
        self.assertEqual(res["decisao"], "avisar")
        self.assertTrue(any("descarte-arquivo" in a for a in res["avisos"]))
        cfg = self.raiz / "promove.toml"
        cfg.write_text('[harness]\nbloquear = ["descarte-arquivo"]\n')
        res = self.checar(cmd="git restore a.txt", cwd=r, extra_env={"HARNESS_CONFIG": str(cfg)})
        self.assertEqual(res["decisao"], "bloquear")
        self.libera(cmd="git restore --staged a.txt", cwd=r)
        self.libera(cmd="git checkout -b nova", cwd=r)


class Escapes(Base):
    def test_escape_nomeado_libera_so_a_regra(self):
        res = self.libera(cmd="SOVEREIGN_SKIP_GATES=add-tudo git add -A")
        self.assertIn("add-tudo", res["escapados"])
        # escape de outra regra não libera esta
        self.bloqueia("add-tudo", cmd="SOVEREIGN_SKIP_GATES=sudo git add -A")

    def test_all_nao_vale_no_guard(self):
        self.bloqueia("add-tudo", cmd="SOVEREIGN_SKIP_GATES=all git add -A")

    def test_escape_pelo_ambiente(self):
        self.libera(cmd="git add -A", extra_env={"SOVEREIGN_SKIP_GATES": "docrefs,add-tudo"})

    def test_export_vale_para_os_segmentos_seguintes(self):
        self.libera(cmd="export SOVEREIGN_SKIP_GATES=add-tudo && git add -A")


class Configuracao(Base):
    def test_desligar_e_apenas_avisar(self):
        cfg = self.raiz / "aviso.toml"
        cfg.write_text('[harness]\ndesligadas = ["sudo"]\napenas_avisar = ["add-tudo"]\n')
        res = self.checar(cmd="sudo true && git add -A", extra_env={"HARNESS_CONFIG": str(cfg)})
        self.assertEqual(res["decisao"], "avisar")
        self.assertTrue(any("add-tudo" in a for a in res["avisos"]))

    def test_config_achada_por_ancestral(self):
        pasta = self.raiz / "proj" / "sub"
        pasta.mkdir(parents=True)
        (self.raiz / "proj" / ".harness.toml").write_text('[harness]\ndesligadas = ["sudo"]\n')
        env = {k: v for k, v in self.env.items() if k != "HARNESS_CONFIG"}
        r = subprocess.run([sys.executable, str(GUARD), "checar", "--cwd", str(pasta), "--cmd", "sudo true"],
                           capture_output=True, text=True, env=env, check=True)
        self.assertEqual(json.loads(r.stdout)["decisao"], "liberar")


class Hook(Base):
    def rodar(self, evento):
        return subprocess.run([sys.executable, str(GUARD), "hook"], input=json.dumps(evento),
                              capture_output=True, text=True, env=self.env)

    def test_claude_bash_bloqueia_com_exit_2(self):
        r = self.rodar({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.wt),
                        "tool_input": {"command": "git add -A"}})
        self.assertEqual(r.returncode, 2)
        self.assertIn("add-tudo", r.stderr)
        self.assertIn("SOVEREIGN_SKIP_GATES=add-tudo", r.stderr)

    def test_claude_edit_quadro(self):
        r = self.rodar({"tool_name": "Edit", "cwd": str(self.wt),
                        "tool_input": {"file_path": str(self.wt / ".agents" / "agents_work.md")}})
        self.assertEqual(r.returncode, 2)

    def test_codex_comando_em_lista_e_patch(self):
        r = self.rodar({"tool_name": "shell", "cwd": str(self.wt), "tool_input": {"command": ["git", "stash"]}})
        self.assertEqual(r.returncode, 2)
        patch = f"*** Begin Patch\n*** Update File: {self.wt}/.agents/agents_work.md\n@@\n-x\n+y\n*** End Patch\n"
        r = self.rodar({"tool_name": "apply_patch", "cwd": str(self.wt), "tool_input": {"input": patch}})
        self.assertEqual(r.returncode, 2)

    def test_libera_com_exit_0_e_json_ruim_nao_trava(self):
        self.assertEqual(self.rodar({"tool_name": "Bash", "cwd": str(self.wt),
                                     "tool_input": {"command": "git status"}}).returncode, 0)
        r = subprocess.run([sys.executable, str(GUARD), "hook"], input="{nao-json", capture_output=True, text=True,
                           env=self.env)
        self.assertEqual(r.returncode, 0)
        self.assertIn("ilegível", r.stderr)

    def test_registro_sem_comando_em_claro(self):
        self.rodar({"tool_name": "Bash", "cwd": str(self.wt), "tool_input": {"command": "cat .env"}})
        log = Path(self.env["XDG_STATE_HOME"]) / "sovereign-harness" / "decisoes.jsonl"
        linhas = [json.loads(x) for x in log.read_text().splitlines()]
        self.assertTrue(any("segredo-env" in x["regras"] for x in linhas))
        self.assertNotIn(".env", log.read_text())

    def test_config_para_scripts(self):
        r = subprocess.run([sys.executable, str(GUARD), "config", "quadro.canonico"], cwd=self.wt,
                           capture_output=True, text=True, env=self.env)
        self.assertEqual(r.stdout.strip(), f"{self.repo}/.agents/agents_work.md")
        r = subprocess.run([sys.executable, str(GUARD), "config", "nao.existe"], cwd=self.wt,
                           capture_output=True, text=True, env=self.env)
        self.assertEqual(r.returncode, 1)

    def test_contexto_lista_quadro(self):
        r = subprocess.run([sys.executable, str(GUARD), "contexto"], cwd=self.wt, capture_output=True, text=True,
                           env=self.env, check=True)
        self.assertIn("1 entrada(s) em andamento", r.stdout)
        self.assertIn("worktree vinculado", r.stdout)


if __name__ == "__main__":
    unittest.main()
