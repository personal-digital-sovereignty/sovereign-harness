# Conclusões — Sovereign Harness

## 2026-10-24 — Asserções do `test_quadro.sh` que não provavam o que diziam

A entrada de 2026-10-23 registrou como limite conhecido que a asserção "`--estrito` reprova" do S6a passaria também por alertas anteriores. Era defeito do teste, e foi corrigido em vez de mantido como limite. Medido no ponto do S6a: com `QUADRO_DIAS_PARADA=99999` o único alerta é o arquivo solto (`--estrito` sai 0 antes e 1 depois); a asserção agora usa essa linha de base e reprova contra o helper anterior ao S6 (`9a2e902`: S6a ×2 e S6c), onde antes passava. Na mesma revisão, as asserções `echo "$saida" | grep -q` viraram here-string — a classe da falsa negativa do `grep -q` sob `pipefail` corrigida nos hooks do #16 continuava no próprio teste, e numa asserção negativa ela vira `ok`. O CI macOS do #16 já tinha pego o `sed -i` só GNU do S6d (`3dd0896`). Não lançado.

## 2026-10-23 — Guarda da `main` do repositório de coordenação e falsa negativa do `grep -q`

No projeto de origem, a `main` do repositório de coordenação andava por caminhos que nenhum gate via: cinco publicações seguidas entraram por `update-ref`, e uma edição em lote não declarada de 3 skills no checkout principal ficou a um `commit -a` de entrar. Ao validar a correção apareceu um defeito antigo do `pre-commit`: `produtor | grep -q` sob `pipefail` falha quando o `grep` sai cedo (SIGPIPE no produtor), e a exceção `docrefs` era ignorada em 152 de 300 execuções; com lista grande, 200 em 200. Este kit era a fonte do `pre-commit` do perfil legado e carregava o mesmo defeito.

Entregue no perfil legado: `reference-transaction` (a `main` só avança; árvore nova passa nos verificadores de skills e links, sobre o commit), gate `main` no `pre-commit`, conclusão de merge que só traz o quadro da `main` liberada, here-string no lugar dos pipes. No núcleo: `quadro.sh saude` acusa edição não declarada; skills `estado-compartilhado-multi-agente` (§7), `vies-de-plausibilidade` (§4) e `quadro-de-trabalho` atualizadas e sincronizadas. Evidência: `templates/git/test_ref_main.sh` 30/30 verde; prova de mutação — `pre-commit` anterior reprova B1, B3, Q1 e P1 (skip ignorado em 3/30), guarda sem ancestralidade reprova A7, sem docrefs reprova A5, com `printf | grep -q` reprova P2; `test_quadro.sh` S6 reprova contra o helper anterior (S6a, S6c); 98 testes do core verdes, incluindo o teste da guarda rodado a partir de uma instalação; shellcheck limpo; sincronia em dia. Limite conhecido: a asserção "`--estrito` reprova" do S6a passaria também por alertas anteriores do mesmo cenário; a prova de S6 está nas asserções de conteúdo. Não lançado.

## 2026-10-21 — Publicação documental: `saude` do quadro e passo "publique e prove"

No projeto de origem, a documentação commitada em branch de agente do repositório de coordenação não chegava à branch principal. Foram medidas 11 branches com commits fora dela; uma ADR citada pelo código ficou 3 semanas só numa branch; 20 entradas do quadro ficaram paradas em "Em andamento". Sem remote nem PR nesse repositório, nada lembrava. Este kit é a fonte da skill e do helper, então a correção entra aqui primeiro e o consumidor adota cópia idêntica.

Entregue: `quadro.sh saude` (também ao fim do `ler`, em stderr) e o passo 7 da skill `encerrar-documentacao`. As skills e os comandos foram sincronizados para os plugins por `scripts/sincronizar.py`. Evidência: S0–S5 herméticos em `templates/git/test_quadro.sh`, verdes com o helper novo; contra o helper anterior as asserções positivas reprovam (8 falhas). C1–C7 continuam verdes, 98 testes do core passam, a sincronia está em dia e o merge-base passa 5/5. Execução no repositório de origem: acusa as 7 branches com conteúdo pendente (2 órfãs), as 3 publicadas e não apagadas e as 20 entradas paradas, em cerca de 2 s. Não lançado.

## 2026-10-15 — P1: merge vinculado à base validada no perfil legado

O `merge_gate.sh` ganha gate `base` incondicional (não herda o skip do `remote`):
re-leitura de head/base após os gates, re-leitura de `origin/main` no último
instante antes do `gh pr merge`, e conferência pós-merge de que o primeiro-pai
da main nova é a base validada. Sem merge queue no servidor a janela não se
fecha pelo cliente: estreita-se a segundos e detecta-se alto, com o par
esperado/medido e ordem de registrar no PENDING.

Evidência: `templates/git/test_merge_gate_base.sh` (T1–T5, repos git reais
descartáveis, `gh` e `git ls-remote` dublês via PATH, sem rede) — 5/5 verde no
gate novo; no gate anterior o T4 (rival na janela) passa cego. Instalador do
perfil legado leva o teste para `.agents/`; CI com `bash -n` nos hooks
portáteis e etapa do vínculo. Publicado no commit `23f1b81` e preparado para a
release 0.3.1.

## 2026-10-15 — Contrato portátil completo preparado para 0.3.0

O instalador passa a criar `docs/` por padrão, com PENDING, ROADMAP, CONCLUSION,
categorias e templates; `--docs-dir` mantém a escolha explícita de outra raiz.
O AGENTS instalado é neutro, e a validação executa apenas gates argv/cwd declarados
pelo projeto, para repositório único, monorepo ou metarrepositório. O perfil
GitHub/Rust/Node continua opt-in. A migração documental exige mapa explícito,
preserva anexos e rejeita colisões, symlinks e links locais quebrados.

Evidência: sincronização de 45 cópias, 80 testes, shellcheck e teste hermético
do quadro passaram em Linux. As quatro superfícies de versão foram alinhadas em
`0.3.0` no commit `6ff3f46`. PENDING mantém apenas certificações de agentes/SO,
paridade en-US, uso externo e os P1/P2 ainda não implementados.

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
