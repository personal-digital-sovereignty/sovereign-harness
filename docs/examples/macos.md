# Portabilidade macOS — achados reais

> Fontes: `sp-assets`/`sp-service` (build wasm, 2026-08-28), E66 (VM Tart,
> 2026-09-27–10-02), auditoria de shell do kit (2026-10-15). Cada item diz o
> que foi medido e onde.

## 1. `stat` tem duas sintaxes (medido no build wasm)

```bash
size=$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f")
```

GNU (`-c`) primeiro, BSD (`-f`) como fallback. Padrão para qualquer script
do kit que mede tamanho. Fonte: `sp-service/scripts/build_treesitter_grammars.sh`.

## 2. `declare -A` quebra no bash 3.2 do macOS (fato de plataforma + grep)

O macOS entrega bash 3.2; array associativo exige bash ≥ 4. O script de
build acima usa `declare -A` — roda com o bash do Homebrew, não com o do
sistema. Checagem que o kit aplica nos próprios scripts (tem de sair vazia):

```bash
grep -rn 'declare -A\|mapfile\|readarray\|\${[a-z_]*,,}' install.sh scripts/ templates/
```

## 3. `readlink` sem `-f` (API, não flag)

Uso portátil: `readlink <link>` (alvo do symlink) existe nos dois. O `-f`
(canonicalize) é só GNU. O `install.sh` usa a forma portátil.

## 4. Toolchain wasm sem Emscripten (medido 2026-08-28)

`tree-sitter build --wasm` baixa e usa o `wasi-sdk` sozinho — nada de
Emscripten instalado à parte, apesar de READMEs de gramática pedirem
`emcc`/CMake. E o achado que justificou buildar nós mesmos: `.wasm` para
`web-tree-sitter` (seção `dylink`, Emscripten) **não** carrega no binding
Rust nativo (espera `dylink.0`) — mesmo sufixo, alvos diferentes
(ADR-020 do projeto de origem).

## 5. Homebrew e app macOS (medido na VM E66)

- `gitleaks`/`trivy`: `brew install` (caminhos nas dicas do `precisa_de`).
- Python do projeto pode viver em `~/.homebrew` (ruff chegou ao perfil `e2e` assim).
- `.app` se lança com `open --env VAR=...` (`launchctl setenv` não propaga);
  `tccutil reset All <bundle>` **não** limpa o grant de Local Network.

## 6. Estado da certificação

CI matriz ubuntu+macos roda a bateria inteira por PR (inclui os testes
herméticos). Windows nativo: sem validação — não anunciar.
