# UC1 — CLI/biblioteca Python, repo único, 1 dev + 1 agente

> Medido: sandbox Linux, 2026-10-15 (ruff + pytest reais, repo descartável).

## Instalar (perfil legado — Python detectado por `pyproject.toml`)

```bash
./install.sh /caminho/cli --git-profile github-rust-node
git -C /caminho/cli config core.hooksPath /caminho/cli/.githooks
```

## O que o push roda (só Python presente)

```
✅ test    # python3 -m pytest -q (suíte inteira)
✅ lint    # ruff check + ruff format --check (só nos .py enviados)
```

Sem gate de tipos universal de propósito: `mypy` só entra se o projeto o
configura — aí o caminho é o perfil portable com gate declarado.

## Canário: o gate morde

Arquivo com `import os` não usado no push:

```
❌ lint
```

Teste quebrado no push:

```
❌ test
```

Push recusado localmente, antes de qualquer CI.
