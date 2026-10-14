# Conclusões — Sovereign Harness

## 2026-10-14 — Configuração inválida interrompe o guard

Perfil ilegível, chave/tipo/regra desconhecidos e HARNESS_CONFIG inexistente
agora recusam a ação com exit 2. A política não é substituída pelos defaults.
Controles negativos executam o hook real contra arquivos TOML descartáveis.

## 2026-10-14 — Avaliação da base e ferramenta de migração

- Avaliação da tag 0.1.0: commit `564ba7f`, [relatório](audits/release-0.1.0.md).
  Os 40 testes originais passaram; limites e achados foram registrados.
- Migração explícita: commit `8c24ef7`, sete testes reais de preservação,
  referências, colisões, symlinks, Unicode e repositório filho independente.
- Estrutura documental e duas skills preparadas em branch. Instalador passa a
  entregar docs e recusa TOML inválido, agente desconhecido e diretório symlink.
  Os dez testes do instalador passaram, incluindo links do projeto instalado.

Não representa nova release nem certificação universal; itens restantes em
[PENDING](PENDING.md).
