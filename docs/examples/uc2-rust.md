# UC2 — Backend Rust, time pequeno

> Medido: sandbox Linux, 2026-10-15 (`cargo` 1.97.1, `clippy`/`rustfmt` reais);
> incidentes citados vêm dos comentários do próprio `pre-push` (2026-09-06/07/10).

## Instalar

```bash
./install.sh /caminho/api --git-profile github-rust-node
git -C /caminho/api config core.hooksPath /caminho/api/.githooks
```

Detecção por `Cargo.toml`. O push roda, nesta ordem:

```
✅ types   # cargo clippy --offline --all-targets -- -D warnings
✅ test    # cargo test --offline
✅ lint    # rustfmt --edition 2021 --check (só nos .rs enviados)
```

## Por que o escopo é por arquivo (3 incidentes reais)

1. `cargo fmt --check -- <arquivos>` **ignora a lista** e enumera os targets
   do crate — push de 2 arquivos conformes reprovava por dívida de dez outros.
   Por isso `rustfmt` direto, nunca via `cargo fmt`.
2. `rustfmt` **atravessa `mod` out-of-line** (`skip_children=true`): sem isso,
   tocar um `mod.rs` arrastava ~60 módulos e cuspia 1075 linhas de diff.
3. `cargo fmt` sem `--edition` assume 2015 e erra parse de código 2021.

Dívida pré-existente nunca bloqueia push alheio; suíte (`clippy`, `test`)
roda inteira de propósito.
