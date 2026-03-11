# AI Shadow Vault

AI Shadow Vault é uma camada local de contexto para desenvolvimento assistido por IA. O objetivo é manter instruções, histórico, planos e skills fora do repositório principal, mas disponíveis dentro do projeto quando necessário.

## O que resolve

O sistema ajuda quando você quer:

- manter contexto de IA fora do Git
- reutilizar planos e histórico entre ferramentas
- suportar vários agentes com a mesma base de contexto
- evitar que worktrees e clones temporários quebrem a resolução do vault

## Peças principais

O sistema combina:

- um data root no diretório do utilizador
- uma workspace local `.ai/` dentro do projeto
- ficheiros gerados e symlinks para agentes específicos

## Data root

Por omissão:

```bash
~/.ai-shadow-vault-data
```

Instalações antigas podem ainda usar:

```bash
~/.gemini-vault
```

Comportamento de migração:

- se `~/.gemini-vault` existir e `~/.ai-shadow-vault-data` não existir, a pasta é renomeada automaticamente
- se ambas existirem, `~/.ai-shadow-vault-data` é a principal
- o conteúdo legado continua legível para compatibilidade

## Resolução estável do projeto

A identidade do projeto é resolvida nesta ordem:

1. `git remote.origin.url`
2. `git rev-parse --git-common-dir`
3. `git rev-parse --show-toplevel`
4. `basename "$PWD"`

Isto evita problemas em:

- repositórios normais
- Git worktrees
- clones temporários como os do Polyscope
- diretórios sem Git

## Instalação

1. Clone o projeto:

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data
```

2. Adicione ao `~/.zshrc`:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

3. Reabra o terminal.

Se quiser apenas recarregar o AI Shadow Vault mais tarde, prefira:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Evite correr `source ~/.zshrc` repetidamente apenas para refrescar o AI Shadow Vault.

4. Dentro de um projeto:

```bash
vault-init
```

Se quiser reabrir a configuração interativa do projeto mais tarde, use:

```bash
vault-init --force-config
```

## Atualizar uma instalação existente

Se você já tem o AI Shadow Vault instalado, o fluxo recomendado é:

```bash
cd ~/Sites/meu-projeto
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Caminho único de upgrade de `1.x` para `2.x`:

```bash
cd ~/Sites/meu-projeto
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context
```

Esta sequência única é necessária porque o `vault-update` antigo da `1.x` faz apenas o pull do pacote. O pós-update automático só passa a funcionar a partir da `2.x`.

Importante:

- o `vault-update` em si precisa atualizar o pacote apenas uma vez
- os passos `vault-init --non-interactive`, `vault-skills standardize`, `vault-skills sync` e `vault-ai-context` devem ser executados uma vez em cada projeto que você queira migrar

Exemplo com dois projetos existentes:

```bash
cd ~/Sites/meu-projeto-a
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context

cd ~/Sites/meu-projeto-b
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context
```

Quando o `vault-update` é executado dentro de um projeto, ele agora faz mais do que um `git pull`. Ele também:

- refresca o vault do projeto em modo não interativo
- normaliza os ficheiros geridos para o formato atual
- volta a sincronizar os targets de skills guardados
- regenera `.ai/context/agent-context.md`

Se executar o `vault-update` fora de um projeto, ele atualiza apenas o pacote.

Se quiser correr manualmente o pós-update do projeto, use:

```bash
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context
```

## Compatibilidade com sistemas operativos

Suporte atual:

- `macOS`: suportado
- `Linux`: não suportado
- `Windows`: não suportado

Motivos:

- a integração de shell depende de `zsh`
- a maior parte dos scripts usa `bash`
- o clipboard espera `pbcopy` no macOS ou `xclip` no Linux
- ainda existem scripts com `sed -i ''`, que é formato de macOS
- a integração com Polyscope é exclusiva de macOS

Neste momento, o pacote deve ser tratado como macOS-only.

## Workspace local `.ai/`

Principais caminhos:

| Caminho | Função |
| :--- | :--- |
| `.ai/rules.md` | regras globais do projeto |
| `.ai/plans/` | planos de implementação |
| `.ai/docs/` | documentação local |
| `.ai/context/archive/` | sessões arquivadas |
| `.ai/context/agent-context.md` | contexto portátil para prompts |
| `.ai/reviews/` | artefactos de review guardados |
| `.ai/skills/ACTIVE_SKILLS.md` | bundle das skills ativas |

## Comandos principais

| Comando | Função |
| :--- | :--- |
| `vault-init` | inicializa o vault do projeto, os symlinks e a workspace `.ai/` |
| `vault-ai-resume` | mostra a última sessão e planos ativos |
| `vault-ai-save` | arquiva a sessão atual |
| `vault-ai-context` | gera `.ai/context/agent-context.md` |
| `vault-review` | prepara um prompt estruturado de code review e o caminho de saída |
| `vault-ai-stats` | mostra métricas da cache local |
| `vault-check` | verifica o vault |
| `cc` | fluxo rápido de contexto para Claude |
| `vault-skills` | gere as skills universais |
| `vault-user-stories` | prepara um prompt de planeamento com user stories e o caminho de saída |
| `vault-breakdown` | alias para `vault-user-stories` |

## Exemplos rápidos

### Exemplo 1: Setup inicial

```bash
cd ~/Sites/meu-projeto
vault-init
```

### Exemplo 2: Criar plano e contexto

```bash
.ai/agents/plan-creator.sh "Refatorar faturação"
vault-ai-context
```

### Exemplo 2b: Gerar prompt de user stories

```bash
vault-user-stories "Implementar login OAuth"
```

Alias:

```bash
vault-breakdown "Implementar login OAuth"
```

### Exemplo 3: Preparar Claude

```bash
cc
```

### Exemplo 4: Ativar skills para Laravel Nova

```bash
vault-skills activate --preset laravel-nova
vault-skills sync native context editors
vault-skills status
```

### Exemplo 5: Atualizar uma instalação antiga

```bash
cd ~/Sites/meu-projeto
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

### Exemplo 6: Preparar review de alterações staged

```bash
vault-skills activate --preset reviewing-laravel
vault-skills sync native context editors
vault-review --scope staged
```

## Ficheiro de contexto portátil

Para ferramentas sem clipboard, use:

```text
.ai/context/agent-context.md
```

Exemplo de prompt:

```text
Use .ai/context/agent-context.md como resumo atual do projeto.
Depois siga .ai/plans/refatorar-faturacao.md.
```

## Skills universais

O sistema usa um modelo híbrido:

- `Gemini` e `Codex`: skills nativas globais
- `Claude`, `Junie` e `Opencode`: bundle agregado local
- `Cursor`, `Windsurf` e `Copilot`: regras locais regeneradas

Comandos úteis:

```bash
vault-skills status
vault-skills presets
vault-skills list
vault-skills activate --preset planning
vault-skills activate --preset reviewing
vault-skills activate --preset reviewing-laravel
vault-skills activate --preset reviewing-laravel-nova
vault-skills activate --preset reviewing-filament
vault-skills activate --preset laravel-nova
vault-skills activate --preset filament syncfusion-document-editor
vault-skills sync native context editors
vault-skills standardize
```

Ficheiros principais:

- `.ai/skills/active-skills.txt`
- `.ai/skills/active-skills.json`
- `.ai/skills/ACTIVE_SKILLS.md`

O preset `planning` ativa atualmente:

- `user-stories`

Presets de review:

- `reviewing`
- `reviewing-laravel`
- `reviewing-laravel-nova`
- `reviewing-filament`

Os artefactos de review são escritos em:

```text
.ai/reviews/
```

## Atribuição de terceiros

A skill built-in `code-review` e o fluxo `vault-review` foram adaptados do pacote original [`felipereisdev/code-review-skill`](https://github.com/felipereisdev/code-review-skill).

Esse pacote upstream está licenciado em MIT. O AI Shadow Vault reutiliza e adapta a estrutura do fluxo de review e do prompt em conformidade com a licença MIT.

## Fluxos típicos

### Fluxo com Claude

```bash
cc
.ai/agents/user-stories.sh "Adicionar auditoria"
.ai/agents/plan-creator.sh "Adicionar auditoria"
claude
vault-ai-save
```

### Fluxo com Gemini

```bash
vault-ai-context
.ai/agents/user-stories.sh "Validar arquitetura"
.ai/agents/plan-creator.sh "Validar arquitetura"
vault-skills activate --preset laravel-nova
vault-skills sync gemini
```

### Fluxo de review

```bash
vault-skills activate --preset reviewing-filament
vault-skills sync native context editors
vault-review --scope branch --base main
```

Scopes suportados:

- `vault-review --scope working`
- `vault-review --scope staged`
- `vault-review --scope branch --base main`
- `vault-review --scope commit --commit <sha>`
- `vault-review --scope range --from <sha> --to <sha>`

### Upgrade de projeto antigo

```bash
vault-skills standardize
```

Este comando cria backups antes de reescrever os ficheiros geridos para o formato atual.

## Troubleshooting

### O `cc` não copia nada

- No macOS, confirme que `pbcopy` está disponível
- No Linux, instale `xclip`
- Mesmo sem clipboard, o `cc` continua a regenerar `.ai/context/agent-context.md`

### As skills parecem duplicadas ou os ficheiros antigos ficaram confusos

Execute:

```bash
vault-skills standardize
```

Isto cria backups e reescreve os ficheiros geridos para o formato atual.

### A ferramenta não consegue usar contexto por clipboard

Use:

```text
.ai/context/agent-context.md
```

e, quando necessário:

```text
.ai/skills/ACTIVE_SKILLS.md
```

### Linux e Windows

Não são plataformas suportadas por este pacote neste momento.

## Guias relacionados

- [AI_CACHE_GUIDE.md](./AI_CACHE_GUIDE.md)
- [SUPERPOWERS_GUIDE.md](./SUPERPOWERS_GUIDE.md)
- [CLAUDE_WORKFLOW_FAQ.md](./CLAUDE_WORKFLOW_FAQ.md)
- [GEMINI_WORKFLOW_GUIDE.md](./GEMINI_WORKFLOW_GUIDE.md)
