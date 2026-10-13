---
name: governanca-de-decisao
description: Como decisões são classificadas, propostas, aprovadas e registradas no método — os três tipos de GAP (código, estrutural, contratual), quando abrir ADR e quando não, épico e insight, o par de registros PENDING/CONCLUSION, o papel de aprovação do dono, e pressupostos declarados. Carregar antes de classificar um problema, antes de abrir ADR/épico/insight, ao fechar qualquer entrega (de qualquer tamanho), e quando um item parecer "nunca ter sido tratado".
---

# Governança de decisão — o porquê, o quê, o amanhã e os obstáculos

Quatro instrumentos, fronteiras rígidas:

| Instrumento | Responde | Público |
|---|---|---|
| **ADR** | por que decidimos assim | engenharia |
| **CHANGELOG** (por repositório) | o que mudou | quem usa |
| **Roadmap / PENDING** | o que está aberto, em que ordem | todos |
| **GAP** | qual é o obstáculo e de que tipo | todos |

## Os três tipos de GAP — três tratamentos

1. **GAP de Código** (débito isolado, falta de teste, otimização, lib menor): **nunca exige ADR**. Resolva, registre a tarefa, feche no CHANGELOG (`[Fix]`/`[Refactor]`/`[Chore]`).
2. **GAP Estrutural** (gargalo de arquitetura, troca de dependência central, mudança que atravessa módulos/repositórios): **ADR antes de abrir o terminal**. Roadmap expõe → ADR decide (Contexto/Decisão/Consequências) → engenharia executa → CHANGELOG anuncia, citando a ADR.
3. **GAP Contratual** (SLA, prazo externo, obrigação regulatória): filtro de prioridade máxima; a ADR registra explicitamente o trade-off assumido sob prazo.

Severidade não decide ADR — **raio de impacto decide**. Caso de origem: 20 achados de segurança, zero ADRs próprias; todos eram GAP de Código.

## ADR: quando, como, e quando NÃO

- Numeração global num índice único (nunca reiniciada por repositório); confira o próximo número livre antes de criar.
- Template de 5 seções: Status · Contexto · Decisão · Consequências · Referências. Contexto cita achado concreto (arquivo, comportamento, incidente), nunca abstração. Consequências listam o lado ruim ao lado dos ganhos.
- Status: Proposto → Aceito | Rejeitado | Descontinuado | Substituído. **Aceite é do dono do projeto.** O agente propõe, mede, e registra; não aceita a própria proposta.
- **Nunca ADR preventiva**: escreve-se quando o time vai de fato atravessar o abismo, não por antecipação.
- **Anti-"só desta vez"**: toda exceção a um princípio documentado (fail-loud, zero-trust) precisa de ADR própria declarando a exceção. Se não vale ADR, não é exceção — é bug.
- Rejeições ficam escritas com motivo, para nenhuma sessão futura reintroduzi-las como "melhoria óbvia".
- Quantificador em ADR ("todos os N") só com a contagem rodada e o comando colado.

## Épico e Insight

- **Épico**: frente de trabalho com fases, aceites e dependências, num documento próprio; o roadmap aponta para ele.
- **Insight**: registro de investigação, análise ou decisão de planejamento que **não é ADR nem épico** (ex.: comparação de opções, auditoria, mapa de prioridades). Declara no topo o tipo, a decisão do dono (se houve) e o que NÃO decide. Fatos não medidos continuam gates; o insight não os converte em conclusão.

## PENDING e CONCLUSION — o par que não tem exceção

- **PENDING** só tem o que está genuinamente aberto.
- **CONCLUSION** é o log cronológico: tudo que foi entregue, resolvido, decidido ou descartado entra lá, com referência ao PR/commit, e sai do PENDING.
- **Toda entrega fecha nos dois**, de qualquer tamanho — fix de uma linha, fase de épico, decisão de ADR, achado de investigação. Item que entra e sai sem registro deixa lacuna de histórico.
- Nunca re-adicione ao PENDING algo concluído; para reabrir, crie entrada nova apontando para o registro histórico.
- Achado não corrigido na rodada vira linha no PENDING **no ato**. Relatório, PR e mensagem de commit são registro histórico, não fila de trabalho.

## Pressuposto declarado

Ao decidir algo que assume "uma máquina, um usuário, um processo" (ou qualquer outro contexto de produto), **nomeie o pressuposto** na ADR/CHANGELOG. Pressuposto declarado vira dívida rastreável; implícito vira surpresa no dia da migração. Não pague agora o custo do cenário futuro — registre. Quando duas formas têm custo parecido e só uma sobrevive ao cenário futuro, escolha essa.

## Aprovação: o que é do dono

Aceite de ADR, publicação de release, mudança de configuração do usuário, instalação de dependência de sistema, publicação em lugar público e qualquer exceção a princípio. O agente chega com a proposta medida e o comando pronto; a decisão não é dele.
