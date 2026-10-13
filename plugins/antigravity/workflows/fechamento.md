---
description: Ritual de fechamento de entrega — validação, registros centrais, branches, quadro e handover
---

Feche a entrega: (o que o usuário pediu ao acionar este workflow)

1. **Validação**: rode o checklist do comando `validar`. Não avance com item em aberto não declarado.
2. **Documentação viva** do(s) repositório(s) afetado(s): `CHANGELOG.md` e `ROADMAP.md`; versão semântica conferida nos manifestos se houve troca de versão.
3. **Registros centrais** (skill `governanca-de-decisao`): o item sai do PENDING (ou é marcado concluído) **e** o desfecho entra no CONCLUSION com data e PR/commit. Sem exceção de "pequeno demais".
4. **Merge** só pelo merge gate configurado (`[harness].merge_gate`), nunca o merge direto da plataforma.
5. **Branches**: mergeou, apague local e remota com prova por dois métodos (skill `varredura-git-multi-repo`); worktrees temporários removidos depois de conferir que não guardam arquivo não versionado.
6. **Varredura**: nenhum commit, stash ou worktree seu ficou órfão em nenhum repositório.
7. **Quadro**: mova sua entrada para "Concluído recentemente" (comando `quadro encerrar`).
8. **Handover**: resumo do que foi feito, do que falta e de qualquer hipótese refutada no caminho.

Relate o que aconteceu, inclusive o que deu errado e como foi corrigido.
