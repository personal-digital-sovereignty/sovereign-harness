# ADR-001 — Documentação de engenharia e separação das políticas do projeto

Status: Proposto para revisão da implementação. Data: 2026-10-14.
Escopo solicitado: harness agnóstico e migração documental para `docs/`.

## Contexto

A [avaliação da 0.1.0](../audits/release-0.1.0.md) encontrou convenções de stack,
forge, topologia e documentação herdadas da origem. Projetos existentes também
podem já ter `docs/`, instruções e hooks; a instalação deve preservar esse trabalho.

## Decisão em implementação

- `docs/README.md` descreve a organização. `PENDING.md` contém pendências;
  `ROADMAP.md`, direção e sequência; `CONCLUSION.md`, desfechos rastreáveis.
- Categorias: `insights`, `adr`, `audits`, `security-audit`, `templates`,
  `design-system`, `epics`, `gaps`; `architecture` e `runbooks` preservam a
  distinção entre desenho e operação. Categoria vazia tem guia, não conteúdo fictício.
- `AGENTS.md` fica na raiz como entrada dos agentes. Método reutilizável fica
  em skills; regras e incidentes específicos permanecem no projeto consumidor.
- Épico descreve resultado e aceites; ADR registra decisão; gap registra obstáculo;
  insight registra investigação. Relações são links relativos; decisão aceita
  não é inferida da existência de um link. Aceite segue a autoridade do projeto.
- A migração usa mapa explícito de origem/destino com hashes, preserva arquivos
  e corrige referências por origem. Não reclassifica decisões históricas nem
  reabre épicos encerrados. Conflitos não são sobrescritos.
- Núcleo do método independe de stack, forge e topologia. Integrações específicas
  são identificadas como adaptadores/perfis; suporte é declarado conforme testes.

## Consequências

Navegação e vínculos ficam previsíveis. Skills mantêm semântica e verificadores
conferem integridade mecânica; nenhuma das duas substitui a outra. O custo é
migrar consumidores e preservar links históricos. Não converter todo texto antigo
em novos IDs ou estados automaticamente: isso criaria decisões não tomadas.

Uma estrutura de pastas, isoladamente, não fecha os P1 nem certifica portabilidade.
Essas entregas ficam rastreadas com aceites próprios.

## Alternativas

Só renomear os dois registros mantém a mistura entre fila e direção. Uma base
externa de conhecimento acrescenta infraestrutura e reduz a portabilidade do Git.
Copiar o AGENTS da origem perpetua dependências locais. Mantemos Markdown e Git.
