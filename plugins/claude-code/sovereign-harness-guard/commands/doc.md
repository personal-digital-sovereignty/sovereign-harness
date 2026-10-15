---
description: Classifica um documento novo ou existente (épico, GAP, insight, ADR) na pasta certa e confere os links Epic↔ADR com o verificador de refs
argument-hint: "<o que classificar: arquivo, ideia ou decisão>"
---

Documento: $ARGUMENTS

Siga a skill `doc-governance`.

1. **Classifique antes de escrever**: épico · GAP (código/estrutural/contratual?) · insight · ADR (precisa mesmo? comando `/adr` decide).
2. Crie/mova para a pasta da tabela da skill, com o nome no padrão existente.
3. **Amarre Epic↔ADR nos dois sentidos** (lista no épico + referência na ADR).
4. **Rode o verificador** (`python3 .harness/verificar_refs.py --docs <docs> --raiz .`) e corrija o que ele apontar — renomeação sem verificador é quebra silenciosa.
5. Feche nos registros (PENDING/CONCLUSION) e nos índices (ADR-INDEX) **no mesmo commit**.
