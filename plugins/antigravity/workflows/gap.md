---
description: Classifica um problema (GAP de Código, Estrutural ou Contratual) e o registra no PENDING no ato
---

Problema: (o que o usuário pediu ao acionar este workflow)

1. **Meça antes de registrar**: reproduza e cole o erro/mecanismo exato. Suspeita não é GAP.
2. **Classifique** (skill `governanca-de-decisao`): Código (resolve sem ADR) · Estrutural (ADR antes de executar) · Contratual (prioridade máxima, ADR registra o trade-off).
3. **Cabe corrigir agora**, num commit próprio, com A/B que prova o defeito? Então corrija — registrar não substitui consertar (skill `disciplina-de-validacao`).
4. Senão, **registre no PENDING no ato**, na seção do tipo, com: data, origem (onde foi achado), mecanismo medido, impacto, próximo passo e o que NÃO foi provado.
5. Nunca deixe o achado só no PR, no commit ou no relatório.
