# Exemplos de uso (UC1–UC6) + macOS

Casos reais, com comandos e saídas medidas — não tutoriais hipotéticos. Cada
arquivo diz **onde foi medido** (sandbox Linux desta sessão, CI, ou histórico
do Sovereign Pair com data). O que ainda não foi medido está rotulado.

- [UC1 — CLI Python, repo único](uc1-python-solo.md)
- [UC2 — Backend Rust](uc2-rust.md)
- [UC3 — Frontend Node/Svelte](uc3-node.md)
- [UC4 — Monorepo multi-stack](uc4-monorepo.md)
- [UC5 — Meta-repo multi-agente](uc5-metarepo.md)
- [UC6 — Adoção só-CI](uc6-somente-ci.md)
- [Portabilidade macOS](macos.md) — achados reais (sp-assets, E66, build wasm)

## Matriz de certificação (só o medido)

| Stack | Linux | macOS | Windows |
|---|---|---|---|
| Python (pytest + ruff) | ✅ medido aqui (2026-10-15, ruff + pytest reais) | matriz CI deste PR em diante | não coberto |
| Rust (clippy + test + rustfmt) | ✅ medido aqui (cargo 1.97.1) | matriz CI deste PR em diante | não coberto |
| Node (npm check + test + prettier) | ✅ despacho medido; scripts do projeto | matriz CI deste PR em diante | não coberto |
| Hooks portáteis | ✅ suíte + instalador | matriz CI deste PR em diante | não coberto |

Regra do ROADMAP: nada fora desta tabela pode ser anunciado como suportado.
Windows nativo segue sem validação própria.
