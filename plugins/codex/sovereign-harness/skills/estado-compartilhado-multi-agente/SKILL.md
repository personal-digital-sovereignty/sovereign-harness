---
name: estado-compartilhado-multi-agente
description: Como não estragar o ambiente de outras sessões que trabalham na MESMA árvore — worktree derivado de main local desatualizado, arquivo inteiro sobrescrito por versão antiga, rm que atravessa symlink, npm install que materializa node_modules compartilhado, e o HEAD que outra sessão move debaixo de você. Carregar antes de criar git worktree, antes de qualquer rm/mv fora do seu diretório, antes de npm install/update, e antes de interpretar um erro de build que "apareceu do nada".
---

# Estado compartilhado — o que quebra quando vários agentes usam a mesma árvore

Nenhum destes casos é falta de conhecimento técnico. Todos são a mesma falha de método:

> operar sobre um estado compartilhado presumindo que ele é o que você espera, em vez de conferir que é.

A conferência custa um comando. O erro custa o trabalho de outra sessão — e costuma aparecer disfarçado de outra coisa.

## 1. Worktree derivado de `main` LOCAL herda o atraso dele

O `main` local de um repositório cujo diretório principal está na branch de outra sessão não é atualizado — você não pode dar `checkout main && pull` ali sem sequestrar o trabalho dela.

```bash
git fetch origin && git worktree add -b <agente>/<slug> <caminho> origin/main
```

Correção importante, medida: a branch atrasada NÃO reverte o que `main` ganhou — o merge de três vias preserva os dois lados. O custo real é trabalhar sobre base velha (conflito, divergência entre repositórios).

## 1b. O caso que realmente apaga trabalho: arquivo inteiro sobrescrito com versão antiga

Uma branch EM DIA com `main` cujo commit sobrescreve um arquivo inteiro com uma versão velha (um `cp` malfeito) carrega a remoção explícita no diff; o merge a aplica sem conflito. Não há gate possível — é indistinguível de remoção deliberada. Defesa: olhar o `git diff` depois de qualquer `cp`/`mv`/geração por script.

## 2. `rm` atravessa symlink e apaga o alvo

O `node_modules` de um worktree costuma ser symlink para o do diretório principal. `rm -f "$WT/node_modules/pacote"` apaga o pacote da sessão vizinha. Antes de escrever fora do seu diretório: `readlink -f <caminho>`. Se sair da sua área, não é seu.

## 3. `npm install`/`update` num worktree materializa o `node_modules`

Substitui o symlink por diretório real, quebra links relativos internos e produz erros de tipagem que parecem do seu diff (caso de origem: 24 erros falsos). Instale no diretório principal.

## 4. O `HEAD` do diretório principal se move sem aviso

Entre criar a branch e commitar, outra sessão pode ter feito checkout no mesmo diretório. Caso de origem: o commit foi para `main` e a branch ficou vazia. Confirme `git branch --show-current` imediatamente antes de cada `git add`.

## 5. O index compartilhado tem trabalho alheio staged

Nunca `git add -A`/`git add .`. Adicione por nome; antes do commit confira `git diff --cached --stat` (o que vai) e `git diff` (o que falta). Para commitar um único arquivo sem levar o staged alheio: `git commit <caminho> -m ...`.

## 6. A pilha de stash é compartilhada

Ela é a mesma para todos os worktrees. `git stash pop` pode pegar o trabalho de outra sessão. Prefira commit WIP; se precisar, `git stash push -u -m <tag-unica>`, guarde o SHA, `git stash apply <sha>`, e `drop` pela referência achada pela tag.

## Regra prática

| Vou... | Confira com |
|---|---|
| criar worktree | `git fetch origin` e derivar de `origin/main` |
| apagar/mover arquivo | `readlink -f` no caminho |
| instalar dependência | `ls -la node_modules \| head -1` |
| commitar | `git branch --show-current` e `git diff --cached --stat` |
| propagar o mesmo arquivo para N repos | `md5sum` nos N |

## A lição maior

Um guardrail construído sobre diagnóstico não testado herda o erro do diagnóstico e o impõe a todos, com autoridade de ferramenta. Caso de origem: o aviso "branch atrás de main" nasceu como gate bloqueante sobre a crença (falsa) da reversão; reprovava trabalho legítimo e não pegava o caso real (1b). Virou aviso. Antes de transformar uma conclusão em gate, refute a conclusão.
