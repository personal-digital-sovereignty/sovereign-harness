# Documentação de engenharia

Este diretório é a fonte documental deste projeto ou do conjunto de repositórios explicitamente coordenado por ele. Consulte as instruções em `../AGENTS.md`.

| Documento/pasta | Responsabilidade |
|---|---|
| [PENDING](PENDING.md) | Trabalho aberto, impedimentos e próximo passo; aponta para detalhes |
| [ROADMAP](ROADMAP.md) | Resultados desejados, sequência, dependências e critérios de priorização |
| [CONCLUSION](CONCLUSION.md) | Entregue, resolvido, descartado ou decidido, com evidência e commit/PR |
| [architecture](architecture/README.md) | Arquitetura vigente, fronteiras e contratos |
| [epics](epics/README.md) | Frentes com resultado, fases e aceites |
| [gaps](gaps/README.md) | Obstáculos medidos; implementação, estrutura ou contrato |
| [adr](adr/ADR-INDEX.md) | Decisões, alternativas e consequências; autoridade de aceite explícita |
| [insights](insights/README.md) | Investigações, hipóteses e alternativas ainda sem compromisso |
| [audits](audits/README.md) | Auditorias gerais com escopo, método e evidências |
| [security-audit](security-audit/README.md) | Auditorias de segurança e evidências publicáveis |
| [design-system](design-system/README.md) | Tokens, componentes, acessibilidade e linguagem visual, quando aplicável |
| [runbooks](runbooks/README.md) | Procedimentos operacionais reproduzíveis |
| [templates](templates/README.md) | Modelos para novos documentos |

## Relações e manutenção

Um insight pode originar épico ou gap; um épico pode exigir decisões registradas em ADRs. Cada documento liga a sua origem e seus dependentes. Uma ADR pode servir a vários épicos; uma correção local pode não exigir nenhuma ADR. Não criar documentos só para preencher a árvore.

IDs permanecem estáveis após conclusão. Mudar estado não muda o arquivo de categoria. PENDING contém links e próximo passo; CONCLUSION registra o desfecho; ROADMAP registra direção, sem copiar a fila de bugs. Reabertura é novo registro vinculado ao histórico.

Em metarrepositório, declarar quais documentos e IDs são centrais e quais pertencem aos membros. Não inferir membros por prefixo de pasta nem duplicar decisões. Em repo único, esta raiz é suficiente. Idioma, responsáveis, ferramentas e aprovação são políticas do projeto.
