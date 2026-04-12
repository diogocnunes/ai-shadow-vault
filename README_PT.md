# AI Shadow Vault

O AI Shadow Vault é uma ferramenta shell-first que mantém ficheiros de adapter de IA fora do Git e cria links desses ficheiros dentro de cada projeto.

Mantém-se intencionalmente pequeno:
- adapters gerados vivem num vault externo
- o projeto só liga `.ai/docs` e `.ai/plans`
- as exclusões Git são locais e idempotentes
- não existe sistema de memória, skills, arquivo ou runtime de tarefas

## Instalação

O Homebrew é o canal principal.

```bash
brew tap <your-tap>
brew install ai-vault
ai-vault
```

Se estiver a usar o repositório em modo source:

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
echo 'source ~/.ai-shadow-vault/scripts/shell_integration.zsh' >> ~/.zshrc
source ~/.zshrc
ai-vault
```

## Primeira Execução

Execute:

```bash
ai-vault
```

Se ainda não existir config global, o AI Shadow Vault arranca um setup curto e grava a configuração em:

```text
$XDG_CONFIG_HOME/ai-shadow-vault/config.json
```

Fallback:

```text
~/.config/ai-shadow-vault/config.json
```

O wizard pede apenas:
- caminho base do vault
- adapters ativos
- toggle de instruções RTK

O default sugerido é:

```text
~/.ai-shadow-vault-data
```

Se existirem pastas sincronizadas compatíveis, também aparecem como opções.

## CLI Principal

```bash
ai-vault install
ai-vault init
ai-vault update
```

### `ai-vault install`

Corre o setup inicial ou reconfigura a config global existente.

### `ai-vault init`

Liga o projeto atual ao vault externo configurado.

Ele:
- resolve uma identidade estável partilhada entre worktrees Git
- usa o caminho base configurado
- gera apenas os adapters selecionados
- liga `.ai/docs` e `.ai/plans`
- trata reparações e migrações com confirmação
- atualiza `.git/info/exclude` de forma idempotente

### `ai-vault update`

O comportamento depende do modo de instalação:
- instalação Homebrew: informa para correr `brew upgrade ai-vault`
- instalação source/git: atualiza o checkout a partir de `origin/main`
- instalação empacotada sem git: informa para reinstalar a release mais recente

## Layout do Vault Externo

Cada projeto resolve para:

```text
<vault_base_path>/<project-slug>-<hash>/
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  docs/
  plans/
```

Dentro do projeto:

```text
.ai/
  docs -> external/docs
  plans -> external/plans

AGENTS.md -> external/AGENTS.md
CLAUDE.md -> external/CLAUDE.md
GEMINI.md -> external/GEMINI.md
```

Só os adapters selecionados na config global são gerados e ligados.

## Identidade do Projeto

A identidade do vault é estável entre worktrees Git.

Raiz de identidade:
- repositório Git: raiz comum do repositório
- projeto sem Git: `realpath(project root)`

Hash:
- `sha1(realpath(identity-root))`
- primeiros 8 caracteres hexadecimais

Formato final:

```text
<slug>-<hash>
```

## Geração dos Adapters

Adapters suportados:
- `CLAUDE.md`
- `AGENTS.md`
- `GEMINI.md`

Todos os adapters são gerados a partir do mesmo modelo interno de instruções.

Factos detetados no repositório podem alterar o output:
- Pest em `composer.json`
- Playwright em `package.json`
- Laravel em `composer.json`
- disponibilidade do RTK via `command -v rtk`

As instruções RTK só entram quando:
- o RTK está disponível nesse momento
- a config global tem o extra RTK ativo

## Exclusões de Git

O AI Shadow Vault gere apenas `.git/info/exclude`.

Bloco gerido:

```text
# >>> ai-shadow-vault >>>
/.ai/
/CLAUDE.md
/AGENTS.md
/GEMINI.md
# <<< ai-shadow-vault <<<
```

O bloco é gerado a partir dos adapters ativos. `.gitignore` nunca é modificado.

## Migração e Reparação

Para `.ai/docs` e `.ai/plans`:
- diretórios reais são tratados como conteúdo do utilizador
- a migração pede confirmação
- conflitos de nome são preservados com:

```text
name.migrated-YYYYMMDD-HHMMSS.ext
```

Para adapters na raiz do projeto:
- symlink em falta: criar
- symlink correto: no-op
- symlink errado: reparar com confirmação
- ficheiro real: mostrar diff e pedir confirmação antes de substituir

## Idempotência

Execuções repetidas de `ai-vault init` são desenhadas para ser idempotentes:
- sem symlinks duplicados
- sem entradas duplicadas no exclude
- sem reescritas desnecessárias
- sem alterações quando o projeto já está correto

## Pastas Sincronizadas

Pode apontar o caminho base do vault para uma localização sincronizada, por exemplo:
- Google Drive
- Dropbox
- outra pasta local sincronizada

Essa escolha é configuração da máquina, não configuração do projeto.

## Comandos de Compatibilidade

Continuam disponíveis como wrappers de compatibilidade:

```bash
vault-init
vault-update
```

Encaminham internamente para a nova CLI e mostram uma nota curta. Existem para não quebrar utilizadores atuais de imediato.

## Packaging

O repositório inclui:
- entrypoints públicos finos em `bin/`
- lógica runtime em `libexec/ai-vault/`
- fórmula Homebrew em `Formula/ai-vault.rb`
- helper de release em `release/build-homebrew-tarball.sh`
