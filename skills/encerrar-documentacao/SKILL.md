---
name: encerrar-documentacao
description: Mantém o ciclo documental ao concluir, descartar ou reabrir uma entrega, fase, gap ou decisão. Sincroniza PENDING, ROADMAP, CONCLUSION e referências sem apagar evidências nem fechar escopo não validado.
---

# Encerrar a unidade realmente entregue

Leia a política documental do projeto. Identifique a unidade exata: uma fase pode
terminar enquanto o épico continua aberto; implementação não aceita ADR por si.

1. Confira evidências executadas e commits/PRs, limitações e trabalho remanescente.
2. Atualize o documento de origem com resultado, data e links; preserve contexto
   e decisões. Resolvido ou descartado continua na mesma categoria e com o mesmo ID.
3. Remova de PENDING somente o trabalho encerrado. Pendência residual mantém
   descrição concreta, responsável/dependência e próximo passo.
4. Registre o desfecho em CONCLUSION com evidência e commit/PR. Atualize ROADMAP
   apenas quando a entrega mudar sequência, prioridade ou dependência. Atualize
   CHANGELOG no escopo correspondente.
5. Confira os links épico ↔ ADR e gap → origem/resolução. Rejeição/substituição
   de decisão preserva motivo e autoridade segundo a política vigente.
6. Rode os verificadores documentais e confira o diff antes de commitar.

Reabertura é novo evento apontando para o histórico, com motivo e evidência;
nunca apagar conclusão antiga para fazer parecer que o item sempre esteve aberto.
Não inventar teste executado, aceite humano, prazo, versão ou suporte linguístico.
