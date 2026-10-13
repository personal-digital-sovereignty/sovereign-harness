---
trigger: always_on
---

# Leia o AGENTS.md primeiro

Antes de qualquer tarefa neste workspace, leia e siga `/AGENTS.md` (raiz do workspace). Ele é a fonte
única das instruções do projeto; `CLAUDE.md` e `GEMINI.md` são symlinks para ele. Não fique só com o
conteúdo desta regra.

Sem `trigger: always_on` no frontmatter, o Antigravity trata a regra como `manual` e nunca a injeta
sozinho — por isso este arquivo existe com esse cabeçalho. Valide com um canário depois de instalar.
