---
name: guarda-de-transacao-de-ref
description: A guarda que lê `old`/`new` de uma transação de ref infere a AÇÃO pelo VALOR — e o `git pack-refs` emite valor ZERADO, que é a assinatura de uma deleção. Cobre o sintoma intermitente que não reproduz sob demanda, como capturar os dados instrumentando o hook, como discriminar o re-pack de uma deleção real (a recriação que o precede), a prova negativa que impede a porta aberta, e o custo de instrumentar por `core.hooksPath` — que desliga TODOS os outros hooks. Carregar ao escrever ou depurar um hook `reference-transaction`, ao ver o alarme "APAGARIA a branch main" sem nada ter sido apagado, e ao ver `error: task 'pack-refs' failed`.
---

# O valor da transação não é a ação

Todo hook `reference-transaction` faz a mesma inferência: lê `<old> <new> <ref>` e conclui a **ação** pelo **valor** — `new` zerado é deleção, `new` que não descende do `old` é reescrita. A inferência é boa porque, para `git update-ref`, o valor **é** a ação.

**Ela quebra quando outro comando produz o mesmo valor para outra ação.** O `git pack-refs` — que a manutenção automática do git roda sozinha depois de commit, merge e push — emite, para cada ref que empacota, **três** transações na mesma execução:

```
0000…0  →  <sha>    refs/heads/main     (recriação: tirou do loose, escreveu no packed)
<sha>    →  0000…0  refs/heads/main     (a segunda linha)
```

**A segunda linha é indistinguível de uma deleção**, e o hook a lia assim.

## Caso de origem (2026-11-26)

Sintoma: `❌ MAIN NÃO ATUALIZADA — Esta operação APAGARIA a branch main`, junto de `error: task 'pack-refs' failed`, depois de commit/merge/push — **sem nada ser apagado**. Apareceu **cinco vezes** numa sessão e **não reproduzia sob demanda**: `pack-refs --all`, `maintenance run --task=pack-refs`, `gc --auto` e a sequência `switch main` + `merge --ff-only` deram **stdin vazio**, uma por uma.

## Regras

1. **Sintoma intermitente não se conserta por plausibilidade — se instrumenta e se captura.** Não reproduzir sob demanda não é "não existe": é falta de dado. Instrumentar o hook e capturar **61 transações** levou ao mecanismo em minutos, depois de horas de tentativa no escuro. Nada foi alterado antes de o discriminador aparecer nos dados.

2. **Procure o discriminador antes de afrouxar a regra.** Afrouxar (`new` zerado deixa de bloquear) abriria a porta que a guarda existe para fechar. O discriminador que os dados deram: **a recriação precede a "deleção", no mesmo comando, em milissegundos** — então uma **marca** gravada na recriação e consumida pela "deleção" seguinte, com **casamento do sha** e **janela curta** (5 s), separa os dois sem afrouxar o caso real.

3. **Não há discriminador no ambiente — não perca tempo procurando.** Medido: `GIT_REFLOG_ACTION` veio **vazio nas 61 transações**, e as fases `preparing`/`prepared`/`committed` são idênticas em conteúdo. Qualquer campo do ambiente é chute.

4. **A prova que impede a porta aberta é a do caso REAL.** Depois de consertar, prove que o que a guarda protegia **continua protegido**: deleção real da `main` → **rc=1**; "deleção" do `pack-refs` → **rc=0**; e ainda: deleção real **logo depois** (marca já consumida) → **rc=1**, marca **velha** → **rc=1**. Sem a recíproca, um "conserto" que só faz o alarme sumir pode ser uma porta aberta.

5. **Prove com `stdin` forjado.** O hook lê stdin: dá para testar as duas ações sem tocar em ref nenhuma —
   `printf '<sha> 0000…0 refs/heads/main\n' | .githooks/reference-transaction prepared`.

6. **Instrumentar por `core.hooksPath` desliga TODOS os outros hooks.** Ao apontar `core.hooksPath` para um diretório de log, o repositório passa a rodar **só** os hooks que existem lá. No caso de origem, um commit de sonda caiu **na `main`**, porque o gate que barra commit direto na `main` tinha sido substituído pelo instrumento. **O instrumento mudou o que estava sendo medido.** Se for instrumentar assim, use uma **branch** e confira o estado depois; o escape nomeado (`HARNESS_SKIP=main-ref`) existe para restaurar.

7. **Pague a dívida do arquivo que você toca.** O teste da guarda tinha **9 achados `SC2015`** pré-existentes; tocar o arquivo faz o gate `shell` rodar nele, e a regra do projeto é que quem toca paga.

## Checklist

1. O alarme veio de uma ação real ou de um valor que **parece** ação? (capture a transação, não presuma)
2. O sintoma é intermitente? Instrumentei e capturei N, ou estou tentando de novo no escuro?
3. O discriminador separa os dois casos, ou apenas silencia o alarme?
4. Depois do conserto, a ação real **continua** sendo recusada? (rc medido)
5. O teste cobre os **dois lados**, e vive no suite da própria guarda?
6. Se instrumentei por `core.hooksPath`, conferi que não deixei o repositório sem os outros gates?
