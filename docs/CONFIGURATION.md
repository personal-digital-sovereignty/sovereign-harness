# Configurar o harness em um projeto

O padrão de instalação usa gates portáveis: Python 3.11+, Git e Bash para os
hooks. Não escolhe stack, forge, branch principal, scanner, test runner ou membros
pelo nome da pasta. Windows nativo e canários de cada agente exigem certificação
própria; agnosticidade do método não significa execução validada em todo ambiente.

## Validação explícita

Em `.harness.toml`, substituir a seção validation de exemplo; não manter
`gates=[]` junto das tabelas. Configurar os comandos reais de segurança, tipos,
testes, lint, E2E e build que o projeto exige. A ferramenta não conhece a cobertura
de um comando arbitrário; `configured=true` registra que o projeto definiu isso.

```toml
[project]
topology = "repository"
members = []

[validation]
configured = true

[[validation.gates]]
id = "documentation"
argv = ["python3", ".harness/documentation.py", "check"]
cwd = "."

[[validation.gates]]
id = "tests"
argv = ["python3", "-m", "unittest", "discover", "-s", "tests"]
cwd = "."
```

O exemplo é de um projeto Python; substitua o segundo comando pela ferramenta
do seu projeto e acrescente seus gates obrigatórios. Não há shell implícito nem
instalação de dependências automática. Configuração é código confiável do projeto,
revisto antes de execução; o executor não é sandbox para projetos não confiáveis.

`python3 .harness/validation.py check` roda os gates no checkout atual.
No pre-push, todos os refs enviados devem corresponder ao HEAD testado e os
repositórios envolvidos não podem ter alterações rastreadas. Push com outro ref
é recusado explicitamente; não se declara aquele commit validado. O HEAD e o
estado rastreado são conferidos novamente depois dos gates. Deleção pura não
envia conteúdo. Arquivos ignorados e dependências de ambiente não são atestados
por essa comparação.

## Monorepo e metarrepositório

Monorepo: `topology="monorepo"`; cada gate pode usar `cwd="packages/api"` ou
outra unidade. Continua havendo um histórico Git.

Metarrepositório: `topology="meta-repository"`, `members=["api", "web"]`;
cada membro precisa ser um repositório independente. Gates declaram cwd dentro
dos membros listados. Cada membro mantém seus hooks e validação para seus pushes;
o push do meta-repo não publica os membros nem substitui seu controle de versão.
Não há dependência de remote, forge ou nome da branch. Membros externos por
symlink não são atravessados; configure a validação no repositório correspondente.

## Integrações opcionais

`--git-profile github-rust-node` instala o perfil legado de gates, merge por gh
e quadro em main. Seus pressupostos de Rust/Node, origin/main, GitHub e máquina
compartilhada são explícitos; não pertencem ao núcleo portável. Perfis futuros
devem declarar contratos e evidência, sem se apresentar como padrão universal.

`--sem-git` preserva a esteira existente. Arquivos diferentes continuam conflitos
para integração manual; o instalador não substitui hooks do usuário nem ativa
`core.hooksPath` silenciosamente. Atualização gerenciada continua no PENDING.
