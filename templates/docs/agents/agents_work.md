# Quadro de trabalho — quem está fazendo o quê, agora

> Único lugar onde uma sessão enxerga a outra. Caminho canônico: o deste arquivo **no diretório principal,
> na branch principal** — nunca a cópia de um worktree. Edite pelo `.agents/quadro.sh editar` e commite com
> `.agents/quadro.sh commit "docs(quadro): <o que mudou>"` (leva só este arquivo). Protocolo completo na skill
> `quadro-de-trabalho`.

## Como usar (3 momentos obrigatórios)

1. **Antes**: leia tudo; se alguém declarou os mesmos paths, combine em "Notas entre agentes". Acrescente sua entrada.
2. **Durante**: atualize ao mudar de repositório, branch ou escopo.
3. **Ao terminar**: mova para "Concluído recentemente" com PRs e o que ficou aberto; limpe as branches.

Timestamp sempre de `date -u '+%F %H:%M'`. **Paths sob edição** é o campo mais importante.

```markdown
### <agente>/<slug> — <título curto>
- **Início**: AAAA-MM-DD HH:MM (UTC) · **Última atualização**: AAAA-MM-DD HH:MM (UTC)
- **Repositórios**: ... · **Branches**: ... · **Worktrees**: ...
- **Demanda**: ...
- **Paths sob edição**: ...
- **Status**: em andamento | aguardando decisão do dono | em revisão | bloqueado
- **PRs**: ...
```

---

## 🔴 Em andamento

## 🟡 Interrompido / órfão

## 🟢 Concluído recentemente

## Notas entre agentes
