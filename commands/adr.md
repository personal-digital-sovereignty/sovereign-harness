---
description: Abre uma ADR (Proposta) no índice global, só quando a decisão é estrutural e vai ser executada agora
argument-hint: "<assunto da decisão>"
---

Assunto: $ARGUMENTS

Siga a skill `governanca-de-decisao`.

1. **Precisa mesmo de ADR?** Só para GAP Estrutural ou Contratual prestes a ser executado, ou para exceção a princípio documentado. GAP de Código não tem ADR. ADR preventiva não existe. Se não precisa, diga por quê e pare.
2. Confira no índice de ADRs o próximo número livre (e reservas em branches abertas).
3. Escreva pelo template (Status **Proposto** · Data · Repositórios · Contexto · Decisão · Consequências · Referências). Contexto com achados concretos (arquivo, incidente, medição com o comando). Consequências com o lado ruim. Pressupostos declarados quando a decisão assume um contexto de produto. Rejeições com motivo.
4. Nenhum quantificador ("todos", "sempre", "os N") sem a contagem rodada e o comando colado.
5. Atualize o índice; commit `docs(adr): propõe adr-0NN sobre <assunto>`.
6. **Aceite é do dono.** Apresente a proposta e as alternativas; não marque como Aceita.
