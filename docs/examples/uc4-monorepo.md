# UC4 — Monorepo multi-stack (Python + Node + Rust)

> Despacho multi-stack medido em sandbox Linux, 2026-10-15 (as 3 toolchains
> reais num repo só). Configuração portable abaixo é exemplo de referência —
> valide com `python3 .harness/validation.py check` no seu monorepo.

## Perfil legado: todas as stacks presentes rodam

```bash
./install.sh /caminho/mono --git-profile github-rust-node
```

Com `Cargo.toml` + `package.json` + `pyproject.toml` no push:

```
✅ types   # clippy (Rust)
✅ test    # cargo test
✅ lint    # rustfmt (só .rs enviados)
✅ types   # npm run check (Node)
✅ test    # npm test
✅ lint    # prettier (só arquivos enviados)
✅ test    # pytest
✅ lint    # ruff (só .py enviados)
```

Limite honesto do legado: os comandos são os do perfil (um por stack, na
raiz). Precisou de comando **por pacote** (`packages/billing` ≠
`packages/auth`)? Esse é o perfil portable:

```toml
[project]
topology = "monorepo"

[validation]
configured = true

[[validation.gates]]
id = "tests-billing"
argv = ["python3", "-m", "pytest", "-q"]
cwd = "packages/billing"

[[validation.gates]]
id = "tests-web"
argv = ["npm", "test", "--silent"]
cwd = "packages/web"
```

## Origem do desenho

O `elif` excludente original servia 8 repos de stack única; com o primeiro
monorepo real, rodar só a primeira stack casada virou lacuna. A correção não
reinventa o portable dentro do legado: detecção independente por marcadores,
um comando por stack.
