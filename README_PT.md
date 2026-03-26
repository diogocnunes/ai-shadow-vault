# AI Shadow Vault

AI Shadow Vault é uma infraestrutura local de developer experience para desenvolvimento assistido por IA.

Mantém o contexto de IA fora do repositório Git e injeta apenas os ficheiros necessários por projeto.

## O Que Este Pacote É

O AI Shadow Vault é um sistema local baseado em ZSH que normaliza:

- regras e guardrails de projeto
- ficheiros de tarefa e contexto
- fluxo de memória/sessão para agentes
- skills específicas de stack através de packs

Não é um serviço cloud, não é um agente hospedado, e não é plugin de framework.

## Porque Existe

Equipas que usam IA em produção tendem a ter os mesmos problemas:

- ficheiros de contexto poluem histórico de Git
- notas privadas acabam no repositório
- cada projeto segue convenções diferentes
- qualidade dos prompts degrada com o tempo

O AI Shadow Vault resolve isto separando infraestrutura (core) de especialização de stack (packs).

## Público-Alvo

- developers que usam Claude/Codex/Gemini no dia a dia
- equipas que querem setup repetível para IA
- maintainers que exigem controlo local e privacidade

## Visão e Valores

O projeto segue quatro valores base:

1. Privacidade por default: contexto local-first, sem dependência cloud obrigatória.
2. Previsibilidade acima de magia: ficheiros explícitos, comandos explícitos, contratos explícitos.
3. Sustentabilidade a longo prazo: core genérico, inteligência de stack em packs.
4. Adoção sem fricção: funciona com repositórios existentes sem reescrita total.

## O Que Mudou no v5 (Hard Cut)

A partir de `v5.0.0`, o core deixou de fornecer skills movidas via fallback legado.

Quando uma skill foi movida para o pack Laravel, o core retorna:

- `ASV-HARD-MIGRATION-001`

Este hard cut foi intencional para:

- eliminar a perceção errada de "core Laravel-first"
- tornar o core realmente agnóstico à stack
- manter uma única fonte de verdade para skills Laravel (`ai-shadow-vault-laravel`)

## Instalação

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data

# Adicionar ao ~/.zshrc
source ~/.ai-shadow-vault/scripts/shell_integration.zsh

# Recarregar shell
source ~/.zshrc
```

## Atualização

```bash
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

## Arranque Rápido (Projeto Novo)

```bash
cd /caminho/do/projeto
vault-init
vault-ai-context
vault-doctor
```

## Ativar Skills (Pack-first)

```bash
cd /caminho/do/projeto
vault-ext enable laravel
vault-ext enable skills
vault-skills set backend-expert
vault-skills sync
```

Checks úteis:

```bash
cat .ai/extensions/lock.json
cat .ai/skills/ACTIVE_SKILLS.md
```

## Fluxo Diário

```bash
# Refrescar contexto
vault-ai-context

# Trabalhar uma tarefa
vault-task "Implementar funcionalidade X"

# Validar saúde do setup
vault-doctor --strict
```

## Normalizar Projetos de <= 4.x para 5.x

Usar este fluxo para projetos existentes que dependiam de fallback legado.

### Passo 1: Atualizar o core para v5

```bash
cd ~/.ai-shadow-vault
git fetch --tags
git checkout v5.0.0
source ~/.zshrc
```

### Passo 2: Re-inicializar estado do projeto

```bash
cd /caminho/do/projeto
vault-init --non-interactive
```

### Passo 3: Ativar pack obrigatório + workflow de skills

```bash
vault-ext enable laravel
vault-ext enable skills
```

### Passo 4: Reaplicar skills ativas

```bash
# Exemplo
vault-skills set backend-expert
vault-skills sync
```

### Passo 5: Validar estado final

```bash
vault-ai-context
vault-doctor --strict
```

Se aparecer `ASV-HARD-MIGRATION-001`, ative o pack requerido e execute novamente `vault-skills set ...`.

## Guia de Comandos (Para Que Serve Cada Um)

### `vault-init`

Inicializa ou normaliza a estrutura `.ai` e os ficheiros/links geridos do projeto atual.

Opções principais:
- `--optimize`: executa fluxo de otimização (detetar -> planear -> aplicar)
- `--interactive`: ativa prompts/confirmações
- `--non-interactive`: modo seguro para automação (default)
- `--dry-run`: pré-visualização sem aplicar (no fluxo optimize)
- `--yes`: confirma automaticamente prompts
- `--force-config`: alias de compatibilidade (deprecated) para `--optimize --interactive`
- `--herd`: flag de compatibilidade para o configurador
- `--use-gemini` / `--no-use-gemini`: flags de compatibilidade (ferramentas continuam opcionais)
- `--enable-workflow` / `--disable-workflow`: flags de compatibilidade (com aviso de depreciação)

### `vault-update`

Atualiza a instalação local (`~/.ai-shadow-vault`) a partir de `origin/main` e refresca o projeto atual.

Após atualizar (ou se já estiver atualizado), executa:
- `vault-init --non-interactive`
- `vault-ai-context`
- `vault-ext run-hook post-update`

### `vault-ai-context`

Regenera `.ai/context/agent-context.md` com estado de trabalho compacto:
- foco atual
- branch ativa
- planos ativos
- blockers/riscos
- skills ativas

### `vault-task`

Cria/gestiona `.ai/context/current-task.md` no formato canónico.

Subcomandos:
- `new [--mode plan|execute]`: criação interativa de tarefa
- `quick "<goal>" [--mode plan|execute]`: cria rapidamente a partir de uma linha
- `compile [--stdin|--input "<text>"|--file <path>] [--mode plan|execute] [--output-lang en|pt|auto] [--enrich conservative|repo-aware] [--format markdown|json] [--apply]`: compila texto livre para tarefa estruturada
- `show`: mostra o ficheiro de tarefa atual
- `mode [plan|execute]`: ler/definir modo da tarefa
- `done`: arquiva estado com `vault-ai-save`
- `clear`: repõe a tarefa no template
- `archive`: mesmo comportamento de arquivo de `done`

### `vault-doctor`

Comando de saúde/normalização para estrutura e contratos da `.ai`.

Opções principais:
- `--fix`: aplica correções automáticas seguras
- `--fix-strict`: aplica correções estritas (implica `--fix`)
- `--strict`: falha em warnings/erros (útil para checks mais rígidos)
- `--json`: saída legível por máquina
- `--interactive`: fluxo guiado (não combina com `--json` nem `--fix*`)
- `--check <nome>`: executa apenas checks específicos (repetível)
- `--explain <code>`: explica um código de diagnóstico (exemplo: `D003`)

### `vault-ext`

Gestor de extensões/packs por projeto.

Subcomandos:
- `list`: lista extensões disponíveis
- `info <extension>`: mostra metadados/source/kind
- `status`: mostra extensões ativas no projeto
- `enable <extension...>`: ativa extensões; instala packs oficiais quando necessário
- `disable <extension...>`: desativa extensões
- `sync [extension...]`: volta a correr hooks de sync e atualiza lockfile
- `run-hook <hook>`: executa um hook para extensões ativas

### `vault-skills`

Comando de workflow de skills (pack-first no v5).

Subcomandos principais:
- `status`: estado de skills ativas/disponíveis
- `list [--json] [--group <id>] [--source pack|all]`: lista skills disponíveis (agrupadas; pack-first por default)
- `suggest [--json|--plan]`: deteta/sugere skills e recomendações de pack (read-only; não altera estado)
- `auto`: auto-ativa decisões de alta confiança; auto-ativa o pack requerido (`laravel`) para sinais Laravel determinísticos
- `set <skill...>`: define skills ativas
- `sync`: recompõe/sincroniza artefactos de skills ativas
- `explain <skill-id>`: explicação curta do propósito da skill
- `legacy ...`: passthrough para interface legacy do instalador

### `vault-pack validate <pack-dir>`

Valida o schema do manifesto `pack.json` de um diretório de pack externo.

### `vault-ai-save`

Arquiva tarefa/planos em `.ai/archive`, repõe a tarefa ativa, regenera contexto e atualiza índice de docs.

### `vault-ai-resume`

Mostra resumo rápido da tarefa atual, estado de trabalho e últimas entradas de arquivo.

### `vault-ai-stats`

Mostra estatísticas locais do vault (tamanho, contagens de docs/cache/planos/arquivo e estimativa de tokens).

### `cc` e `cx` (aliases de shell)

Disponíveis após carregar a integração:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

- `cc`: executa recap/bootstrap para Claude (`claude-start`)
- `cx`: executa recap/bootstrap para Codex (`codex-start`)

## Packs e Contrato

Packs são repositórios externos (por exemplo, `ai-shadow-vault-laravel`) com contrato mínimo via `pack.json`.

Campos obrigatórios:

- `name`
- `version`
- `description`
- `core_api`
- `capabilities`

Catálogo opcional (para deteção/listagem orientada a metadados):

- `skills/catalog.json`

Referência:

- `docs/pack-contract.md`

## Resolução de Problemas

### `ASV-COMPAT-001`

O intervalo `core_api` do pack não é compatível com a versão do core.
Use release de pack compatível ou atualize o core.

### `ASV-HARD-MIGRATION-001`

A skill pedida já não é fornecida pelo core.
Ative o pack necessário (normalmente `laravel`) e defina a skill novamente.

### `No .ai directory found`

Execute `vault-init` primeiro no projeto.

## Suporte de SO

- macOS
- Linux (ZSH)

## Resumo

AI Shadow Vault é a base local estável.
Packs entregam profundidade de stack.

Core é infraestrutura.
Packs são especialização.
