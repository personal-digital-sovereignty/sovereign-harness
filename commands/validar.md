---
description: Checklist de validação antes de declarar uma tarefa pronta (sem mock, com prova negativa)
argument-hint: "[o que foi alterado]"
---

Aplique as skills `disciplina-de-validacao`, `vies-de-plausibilidade` e `validacao-real-sem-mock` ao trabalho desta sessão: $ARGUMENTS

Responda cada item com evidência executada nesta sessão (comando + saída relevante), nunca com resumo:

1. Que validações eu declarei, e quais executei de fato? Cole a saída.
2. O que eu mexi está coberto pelo que rodei? (runtime ≠ type-check; visual ≠ jsdom; app empacotado ≠ browser)
3. Algum gate reprovou? Terminou em correção do código ou do gate — nunca em escape sem diagnóstico?
4. Algum bug encontrado no caminho ficou sem correção ou sem GAP escrito agora?
5. Todo verificador/teste/filtro que escrevi foi provado no sentido negativo (reprova no estado quebrado)?
6. Afirmei causa raiz? Qual teste a refutaria, e ele rodou?
7. A prova que usei daria o mesmo resultado se eu estivesse errado?
8. O que não consegui validar está escrito com o erro exato?

Se algum item falhar, corrija antes de declarar pronto — ou declare explicitamente o que falta e por quê.
