# Avaliação da release 0.1.0

Data: 2026-10-14. Base imutável: tag `v0.1.0`, commit
`cbd028f659b86a94304a095aac55f34aaec97bef`. Avaliação de código e execução
local em Linux; não equivale à certificação das integrações nos quatro agentes.

## Parecer

A versão é uma extração útil de um método exercitado em produção, mas ainda não
é um harness inteiramente agnóstico. O núcleo do guard é reutilizável; os gates,
o instalador e as instruções ainda transportam pressupostos do projeto de origem.
Renomear pastas melhora navegação, mas não resolve esse acoplamento sozinho.

## Pontos fortes

- Motor único em Python com biblioteca padrão, adaptadores separados e cópias
  verificadas: reduz divergência entre agentes e custo de instalação.
- Regras com origem e severidade identificáveis; escape por regra no guard;
  registro sem o comando em claro. São mecanismos auditáveis.
- Testes com Git real e instalação real. Os 40 testes da release passaram em
  7,269 s nesta execução; a suíte do quadro passou seus dez asserts.
- Quadro usa controle de concorrência e recusa rascunho obsoleto: valor concreto
  para várias sessões sobre a mesma base.
- Instalador preserva arquivos existentes e reporta conflitos; sincronia de
  37 cópias e shellcheck do instalador passaram.
- Reconhece que Antigravity tem instruções, não bloqueio determinístico; declara
  o canário do Claude Code e a versão en-US como pendentes.

## Fraquezas, evidências e prioridades

| Prioridade | Achado na 0.1.0 | Evidência / consequência |
|---|---|---|
| P1 | Configuração inválida não interrompe | Instalar um perfil contendo `[harness` retorna 0. `config harness.escape_env` retorna 0 e `HARNESS_SKIP`, com aviso de uso dos padrões; políticas específicas desaparecem. `core/harness_guard.py:carregar_config`. |
| P1 | Instalador atravessa diretório symlink | `.harness` ligado a outro diretório: instalação retorna 0 e escreve `harness_guard.py` fora do alvo. Reproduzido em diretórios descartáveis. `install.sh:instala`. |
| P1 | Falha de consulta pode virar ausência de checks | `templates/git/merge_gate.sh` usa `gh pr checks ... || echo '[]'`; falha de autenticação/transporte pode seguir pelo caminho de zero checks. Inspeção estática; merge remoto não executado. |
| P1 | Cobertura de linguagem implícita e incompleta | Pre-push só tem tipos/testes para `Cargo.toml` ou `package.json`; projetos Python, Go, Java e metarrepositórios não recebem uma política explícita de cobertura. Rust fixa edition 2021 e offline; Node pressupõe script `check`. |
| P1 | Validação e publicação não estão amarradas ao mesmo estado completo | Pre-push usa o checkout corrente; em push com vários refs a variável `RANGE` termina com um único intervalo. Merge fixa o head do PR, mas não a base remota após os testes. Exige desenho e provas próprios. |
| P2 | Portabilidade depende de convenções locais | `origin/main`, `gh`, `python_workers`, diretório irmão com prefixo `sp-`, symlink de `node_modules`, quadro em main e caminhos absolutos aparecem nos templates. Não descrevem qualquer projeto. |
| P2 | Instalação não é atualização gerenciada | Arquivo diferente vira conflito; não há inventário de versão instalada nem merge de hooks existentes. Conflitos podem deixar instalação parcialmente criada. |
| P2 | Entrada desconhecida aceita | `--agentes inexistente` retorna 0, instala núcleo/docs/skills sem adaptador e não informa erro. Reproduzido. |
| P2 | Governança documental incompleta | PENDING e roadmap se confundem; faltam templates/ciclo de vida de épico, gap e insight, relações verificáveis e verificador documental distribuído. O pre-commit apenas chama um verificador se ele já existir. |
| P2 | Linguagem de regras extrapola contexto | Proibição universal de mock, autoria sempre do dono, `sudo` sempre proibido e branch fixa são políticas possíveis, não invariantes universais. Devem respeitar a política explícita do projeto e a autorização da sessão. |
| P2 | Integração e plataformas não certificadas integralmente | CI cobre Linux; canários da release não provam Windows nativo, macOS nem todas as versões dos agentes. Shell/Bash/symlinks são dependências reais. |

## Limite de segurança

O guard interpreta padrões de comandos e eventos de ferramentas. Não é sandbox,
não controla ações humanas nem impede que código Python ou um executável realize
efeitos equivalentes. A fronteira real continua nos controles do SO, permissões,
Git/CI e revisão. Medição em 38.131 ações de um projeto sustenta calibração naquele
contexto; não mede taxa de falso positivo em outros projetos.

## Direção recomendada

1. Contrato documental em `docs/`, com papéis distintos, vínculos e validação;
   `AGENTS.md` curto como entrada para políticas do projeto.
2. Separar núcleo, adaptadores de agente, adaptadores de forge, perfis de projeto
   e comandos de validação. Perfil explícito para repo único, monorepo ou
   metarrepositório; inventário de membros, sem descobrir escopo por prefixo.
3. Corrigir falhas P1 com reprodução negativa; não anunciar proteção universal.
4. Instalação planejada antes de escrita, validação do perfil e destinos,
   atualização por manifesto e testes de conflito/rollback.
5. Certificação por matriz de topologia, stack, SO, agente e idioma. Estado
   desconhecido deve aparecer como não validado, nunca como sucesso.

O método pode ser agnóstico sem ser neutro: evidências, rastreabilidade e falha
explícita são princípios; ferramentas, permissões, idioma e topologia são escolhas
do projeto. Origem histórica e marca podem permanecer, sem dependência operacional.
