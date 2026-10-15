# Conclusões — Sovereign Harness

## 2026-10-14 — Falhas explícitas e caminhos literais

Adaptador GitHub recusa erro de consulta, resposta inválida, ausência de check,
todos pulados e estados não verdes. Quatro testes do parser exercitam positivos
e negativos; não houve merge remoto nesta validação. Head/base são reconsultados
depois dos gates; atomicidade com a base ainda depende do servidor.
Instalador gera hooks com escaping separado de shell/JSON: comando real executado
num caminho com espaços, aspas e substituições de shell sem executar o conteúdo
do nome. Os 13 testes do instalador passaram. Verificador documental distingue
exemplos em code spans de links reais; oito testes de migração/links passaram.

## 2026-10-14 — Método separado de convenções do projeto de origem

Documentação, fechamento e coordenação por quadro agora declaram quando dependem
de configuração do projeto. O kit não presume meta-repositório, GitHub, PR,
quadro canônico ou mecanismo de merge. Cópias de plugins foram sincronizadas;
67 testes, shellcheck e o teste hermético do quadro passaram em Linux.

## 2026-10-14 — Gates portáveis e topologia explícita

Instalação padrão deixa de presumir GitHub, Rust/Node, origin/main e quadro
compartilhado. Gates são argv/cwd declarados, com membros explícitos no meta-repo.
Perfil incompleto recusa push. Provas reais: repo em trunk sem remote, monorepo,
metarrepositório com membro Git em develop, propagação de exit 7, travessia,
checkout sujo e push de múltiplos refs divergentes. Cinco testes passaram.
Perfil legado permanece opt-in; seus limites estão na configuração e no PENDING.

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
