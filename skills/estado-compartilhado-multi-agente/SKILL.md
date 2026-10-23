---
name: estado-compartilhado-multi-agente
description: Como não estragar o ambiente de outras sessões que trabalham na MESMA árvore — worktree derivado de main local desatualizado, arquivo inteiro sobrescrito por versão antiga, rm que atravessa symlink, npm install que materializa node_modules compartilhado, e o HEAD que outra sessão move debaixo de você. Carregar antes de criar git worktree, antes de qualquer rm/mv fora do seu diretório, antes de npm install/update, antes de publicar na main com o checkout principal sujo de outra sessão (§7), e antes de interpretar um erro de build que "apareceu do nada".
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

## 7. Publicar na `main` do repositório de coordenação com o checkout principal sujo de outra sessão

Num repositório de coordenação sem remote, "merge" é mover `refs/heads/main`, e o diretório principal fica sempre com a `main` em checkout. Quando outra sessão deixou sujo, sem commitar, um arquivo que o seu merge também altera, `git merge` ali **recusa** — por arquivo sujo, não por conflito. As saídas óbvias são ruins: `--autostash`/`stash` mexem na pilha compartilhada (§6) e no trabalho alheio; esperar pode levar horas. Caso de origem: uma correção de 6 arquivos travada porque um deles tinha 14 linhas de edição alheia que nem encostavam no trecho do merge.

```bash
# 1. No SEU worktree: traga a main, valide, confira o que a main vai receber
git merge main
git diff --stat main HEAD           # só os seus arquivos; se aparecer outro, pare

# 2. No principal, pré-checagem (nada é alterado ainda)
git status --porcelain -- <seus arquivos limpos>     # vazio
git diff main NEW -- <arquivo sujo> > p.patch
git apply --check p.patch                            # o seu trecho entra por cima do alheio

# 3. Tudo num comando só, ENCADEADO com && — no shell de ferramenta do agente
#    o `set -e` pode não abortar (medido: `set -e; false; echo x` imprime x)
git update-ref refs/heads/main NEW OLD &&   # CAS: recusa se a main andou
git checkout NEW -- <seus arquivos limpos> &&
git reset -q -- <arquivo sujo> &&           # index ← nova main
git apply p.patch                           # working copy = nova main + edição alheia

# 4. Prova
git diff --cached --quiet                 # nada staged no checkout dela
git diff --stat <arquivo sujo>            # igual ao de antes: só a edição alheia
```

**O passo 3 precisa ser completo**: o `update-ref` move a `main`, mas não toca no index nem nos arquivos. Sem `checkout`/`reset`/`apply`, o index fica com as versões **velhas** dos seus arquivos, e o próximo `git commit -a` da outra sessão **reverte o seu trabalho** sem conflito e sem aviso.

**Com a guarda da ref instalada** (`.githooks/reference-transaction`, perfil legado), o `update-ref` do passo 3 só passa se a `main` estiver avançando e a árvore nova passar nos gates de documentação; recusado, nada mudou — corrija na branch e repita. Se você usar `git merge` e ele for recusado, o git **já terá escrito** o conteúdo na árvore de trabalho do checkout principal (só a ref fica parada). Restaure só os arquivos que a recusa lista (`git restore --source=main --staged --worktree -- ...`), **nunca** com `reset --hard`, que apaga o trabalho não commitado das outras sessões.

**Antes de concluir que o arquivo sujo é trabalho de alguém**, confira que não é cópia velha esquecida: `git log --all --find-object=$(git hash-object <arquivo>)` vazio = conteúdo que não existe em commit nenhum, ou seja, trabalho real. Timestamps idênticos em vários arquivos indicam escrita em lote, não edição à mão. O `quadro.sh saude` acusa arquivo alterado no checkout principal que nenhuma entrada declara em "Paths sob edição".

## Regra prática

| Vou... | Confira com |
|---|---|
| criar worktree | `git fetch origin` e derivar de `origin/main` |
| apagar/mover arquivo | `readlink -f` no caminho |
| instalar dependência | `ls -la node_modules \| head -1` |
| commitar | `git branch --show-current` e `git diff --cached --stat` |
| publicar na `main` com checkout sujo alheio | §7, encadeado com `&&` |
| propagar o mesmo arquivo para N repos | `md5sum` nos N |

## A lição maior

Um guardrail construído sobre diagnóstico não testado herda o erro do diagnóstico e o impõe a todos, com autoridade de ferramenta. Caso de origem: o aviso "branch atrás de main" nasceu como gate bloqueante sobre a crença (falsa) da reversão; reprovava trabalho legítimo e não pegava o caso real (1b). Virou aviso. Antes de transformar uma conclusão em gate, refute a conclusão.
