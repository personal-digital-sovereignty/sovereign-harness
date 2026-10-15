# UC6 — Adoção só-CI (sem hooks no clone)

> Comandos reais, medidos no CI e local em 2026-10-15.

Para projeto que não quer hooks no clone (`--sem-git`): o kit vira 3
verificadores na esteira, sem instalar nada além dos scripts.

```bash
./install.sh /caminho/proj --sem-git --sem-skills
```

```yaml
# .github/workflows/harness.yml (exemplo)
- run: python3 scripts/sincronizar.py --verificar   # se versiona plugins
- run: python3 scripts/verificar_refs.py --docs docs --raiz .
- run: python3 scripts/verificar_adr.py --adr-dir docs/adr
```

Cada um é fail-loud com `arquivo:linha` (ou `arquivo: par esperado/medido`)
e tem prova negativa na suíte do kit. Nenhum exige Python além do 3.11+,
nenhum instala dependência, nenhum fala com a rede.
