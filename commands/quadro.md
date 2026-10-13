---
description: Lê o quadro de trabalho multi-agente e registra/atualiza/encerra a entrada desta sessão
argument-hint: "[ler | iniciar <título> | atualizar | encerrar]"
---

Siga a skill `quadro-de-trabalho`. Ação pedida: $ARGUMENTS (sem ação: `ler`).

1. Descubra o caminho canônico do quadro e o helper em `[quadro]` do `.harness.toml` (procure no diretório atual e nos ancestrais). Sem configuração, pergunte ao dono onde fica o quadro — não presuma.
2. `ler`: mostre as entradas de "Em andamento" e aponte qualquer colisão de **paths sob edição** com o que esta sessão pretende tocar.
3. `iniciar`: obtenha o timestamp com `date -u '+%F %H:%M'`; acrescente a entrada no formato da skill (repositórios, branches, worktrees, demanda, paths sob edição, status); edite SOMENTE o arquivo que o `editar` do helper indicar; commite com o `commit` do helper, levando apenas o quadro.
4. `atualizar`: refaça a leitura antes (outra sessão pode ter escrito), ajuste escopo/paths/status e o timestamp de atualização.
5. `encerrar`: mova a entrada para "Concluído recentemente" com PRs e o que ficou aberto; confirme antes que as branches mergeadas foram apagadas com prova por dois métodos (skill `varredura-git-multi-repo`).

Nunca edite a cópia do quadro dentro de um worktree. Nunca apague entrada de outra sessão sem verificar.
