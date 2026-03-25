# AI Shadow Vault

O AI Shadow Vault é um sistema de contexto portátil e agnóstico de agente para projetos de software.
Ele mantém as instruções de IA organizadas, compactas e consistentes entre ferramentas como Claude Code, Codex, Gemini, Opencode e similares.

## Índice

- [O Que É o AI Shadow Vault](#o-que-é-o-ai-shadow-vault)
- [Para Que Serve](#para-que-serve)
- [Vantagens](#vantagens)
- [A Quem Se Destina](#a-quem-se-destina)
- [Princípios Base](#princípios-base)
- [Ordem Canónica de Autoridade](#ordem-canónica-de-autoridade)
- [Estrutura do Vault](#estrutura-do-vault)
- [Instalação](#instalação)
- [Inicializar um Projeto](#inicializar-um-projeto)
- [Atualização](#atualização)
- [Comandos](#comandos)
- [Workflows do Dia a Dia](#workflows-do-dia-a-dia)
- [Skills e Auto-Deteção](#skills-e-auto-deteção)
- [Extensões Opcionais](#extensões-opcionais)
- [Resolução de Problemas](#resolução-de-problemas)
- [Suporte de SO](#suporte-de-so)
- [Créditos](#créditos)

## O Que É o AI Shadow Vault

O AI Shadow Vault é uma camada local de contexto que:

- mantém contexto de IA fora do histórico principal do repositório
- liga ficheiros adaptadores leves ao projeto (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, etc.)
- mantém ficheiros canónicos de contexto em `.ai/`
- ajuda os agentes a seguirem o mesmo modelo de autoridade, com o mínimo de duplicação

## Para Que Serve

Serve para:

- padronizar instruções entre agentes de IA diferentes
- evitar conflitos de regras espalhadas por vários ficheiros
- manter contexto ativo curto e útil
- preservar continuidade de trabalho sem transformar contexto em logs gigantes
- migrar layouts antigos de contexto com segurança

## Vantagens

Principais benefícios:

- modelo único de autoridade
- contexto ativo compacto e otimizado para IA
- ferramentas opcionais continuam opcionais (com fallback)
- regeneração mais segura com marcadores de ficheiro gerido
- validação e correção com `vault-doctor` e `vault-test`

## A Quem Se Destina

O AI Shadow Vault é indicado para:

- developers que usam IA diariamente em projetos reais
- equipas que precisam de consistência entre ferramentas de IA
- projetos que querem defaults seguros e otimização AI-first opcional

## Princípios Base

- Agnóstico de agente: sem lock-in num único fornecedor
- Agnóstico de ferramenta: RTK/Gemini CLI/Context7 e similares são opcionais
- Contexto compacto: ficheiros ativos não são histórico
- Segurança entre gerido e autoral: ficheiros geridos podem ser regenerados com segurança
- Comportamento explícito, sem magia oculta

## Ordem Canónica de Autoridade

Os agentes devem seguir exatamente esta ordem:

1. `.ai/rules.md`
2. `.ai/context/current-task.md`
3. `.ai/plans/`
4. `.ai/context/project-context.md`
5. `.ai/context/agent-context.md`
6. `.ai/skills/ACTIVE_SKILLS.md`
7. `.ai/docs/`
8. `.ai/archive/` (consulta manual)

## Estrutura do Vault

Caminhos principais:

- `.ai/rules.md`: política canónica
- `.ai/context/current-task.md`: uma única tarefa ativa
- `.ai/context/project-context.md`: factos estáveis do projeto
- `.ai/context/agent-context.md`: continuidade compacta de estado (sem histórico)
- `.ai/plans/`: planos ativos
- `.ai/docs/`: documentação de suporte
- `.ai/skills/ACTIVE_SKILLS.md`: índice de skills ativas
- `.ai/archive/`: material histórico

Ciclo de vida da tarefa:

- `current-task.md` contém apenas a tarefa ativa
- ao concluir, o material da tarefa deve ir para arquivo
- ficheiros ativos não devem acumular histórico

## Instalação

Clonar e preparar diretório base:

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data
```

Adicionar integração no `~/.zshrc`:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Recarregar shell:

```bash
source ~/.zshrc
```

## Inicializar um Projeto

Setup padrão (seguro e não invasivo):

```bash
cd ~/Sites/meu-projeto
vault-init
```

Modo AI-first (detetar -> pré-visualizar -> aplicar):

```bash
vault-init --optimize
```

Apenas preview (sem aplicar alterações):

```bash
vault-init --optimize --dry-run --non-interactive
```

Fluxo interativo de otimização:

```bash
vault-init --optimize --interactive
```

Alias de compatibilidade:

```bash
vault-init --force-config
```

## Atualização

Atualizar pacote e refrescar projeto atual:

```bash
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

O `vault-update` refresca o estado com:

- `vault-init --non-interactive`
- `vault-ai-context`
- hooks de pós-update das extensões ativas

## Comandos

### Comandos core

- `vault-init`
  - opções: `--optimize`, `--interactive`, `--non-interactive`, `--dry-run`, `--yes`, `--force-config`
- `vault-update`
- `vault-doctor`
  - opções: `--fix`, `--fix-strict`, `--interactive`, `--strict`, `--json`, `--check <nome>`, `--explain <código>`
- `vault-test`
  - default: suite rápida (`core` + `bootstrap` + `doctor`)
  - `--all`: suite completa (`core`, `optimize`, `bootstrap`, `task`, `migration`, `doctor`)
  - `--suite <nome>`: `quick|core|optimize|bootstrap|task|doctor|skills|migration|all`
- `vault-bootstrap`
  - `ensure`, `check`, `ack --source <label>`
  - `BOOTSTRAP_ACK` é sinal de auditoria (não garantia técnica)
  - wrappers registam ACK, mas não bloqueiam execução com base apenas no token
  - `BOOTSTRAP_RUNNING=1` evita recursão durante bootstrap
  - `scripts/lib/bootstrap-enforcer.sh` é o único responsável por atualizar `last_check` em `.ai/bootstrap.md` após `ensure` com sucesso
- `vault-context`
  - `refresh`, `trim`
- `vault-task`
  - `new` (wizard interativo), `quick` (rápido), `compile` (compila pedido natural para tarefa estruturada), `show`, `mode`, `done`, `clear`, `archive`
  - `compile` suporta pedidos em PT/EN (texto livre ou semi-estruturado), faz preview por default e só escreve com `--apply`
  - `compile` preserva referências explícitas como `@app/...`, `@lang/...` e URLs no contexto compilado
- `vault-ai-context`
- `vault-ai-save`
- `vault-ai-resume`
- `vault-ai-stats`

### Comandos de skills

- `vault-skills status`
- `vault-skills suggest`
- `vault-skills suggest --json`
- `vault-skills suggest --plan`
- `vault-skills auto`
- `vault-skills set <skill...>`
- `vault-skills sync`
- `vault-skills explain <skill-id>`
- `vault-skills legacy ...` (modo compatível)

### Comandos de extensões

- `vault-ext list`
- `vault-ext info <extensão>`
- `vault-ext status`
- `vault-ext enable <extensão...>`
- `vault-ext disable <extensão...>`
- `vault-ext sync [extensão...]`
- `vault-ext run-hook <hook>`

### Comandos opcionais de workflow

- `vault-review` (também `vault-code-review`, `vault-pr-review`)
- `vault-user-stories` (também `vault-breakdown`)
  - ambos injetam preâmbulo de sessão obrigatório e registam ACK para auditoria (sem gating por token)

## Workflows do Dia a Dia

### 1) Iniciar/refrescar contexto

```bash
vault-bootstrap ensure
vault-context refresh
vault-task show
# atalhos de shell
cc  # preflight para Claude
cx  # preflight para Codex
```

O que acontece:

- `vault-bootstrap ensure` valida o bootstrap e atualiza `.ai/bootstrap.md`
- `vault-context refresh` regenera o `agent-context.md`
- `vault-task show` mostra o estado atual da task
- `cc` / `cx` fazem o preflight de sessão para Claude/Codex e registam ACK (apenas auditoria)

### 2) Executar uma tarefa nova

```bash
vault-task new --mode plan
# ... trabalho de planeamento
vault-task mode execute
# ... trabalho de execução
vault-task done

# Variante para automação
vault-task quick "Implementar login OAuth" --mode plan

# Compilar pedido natural (PT/EN) para task estruturada
vault-task compile --input "Dado que ... Para testar, aceder via Playwright ..."
vault-task compile --file pedido.md --apply
```

No `vault-task new`, o assistente pergunta e já inclui texto de ajuda:

- `Goal (What you need to deliver?)`
- `Context` (com ajuda sobre factos/estado/dependências)
- `Constraints` (com ajuda sobre limites e regras)
- `Success Criteria` (com ajuda de Definition of Done)
- `Validation Instructions` (como validar conclusão, com comandos/browser/tooling)
- `Private Deliverables (Optional)` (artefatos internos)

Após criar a tarefa (`new` e `quick`), executa automaticamente:

- `vault-context refresh`
- `vault-doctor --fix`

Exemplo resumido do diálogo:

```text
$ vault-task new --mode plan
Creating a new task interactively.
Mode help: plan = define strategy first, execute = implementation-focused task.
Mode [plan/execute] [plan]:
Goal (What you need to deliver?):
Context:
Help: Facts needed to execute safely (scope, flow, current state, dependencies).
(finish with an empty line)
Constraints:
Help: Hard requirements, scope limits, non-goals, and rules that must not be violated.
(finish with an empty line)
Success Criteria (one item per line):
Help: Definition of Done: measurable outcomes that prove completion.
(finish with an empty line)
Validation Instructions (one item per line):
Help: How to verify task completion (commands, browser/tooling steps, and expected checks).
(finish with an empty line)
Private Deliverables (Optional):
Help: Internal-only artifacts/paths/checklists (not shown to end users).
(finish with an empty line)
Created: .ai/context/current-task.md
Running post-create maintenance...
- vault-context refresh: ok
- vault-doctor --fix: ok
```

### 3) Verificação de saúde

```bash
vault-doctor
vault-test
```

### 4) Limpeza estrita de adapters legados

Se `vault-doctor --strict` reportar warnings de adapters (`D010`, `D030`), use:

```bash
vault-doctor --fix-strict
```

Este comando substitui os 5 adapters por templates thin-managed e cria backup em:

- `.ai/archive/doctor-backups/adapters-<timestamp>/`

## Skills e Auto-Deteção

O `vault-skills suggest` deteta sinais de stack em ficheiros como:

- `composer.json`
- `package.json`
- `pyproject.toml`
- `requirements.txt`
- `go.mod`

Modelo de decisão:

- `>= 0.80`: candidatos a auto-enable
- `>= 0.50 e < 0.80`: candidatos sugeridos

Use `vault-skills explain <skill-id>` para transparência da recomendação.

## Extensões Opcionais

Extensões são opcionais e por projeto.

Grupos embutidos:

- `planning`
- `review`
- `skills`
- `laravel-stack` (reservado)

Ative apenas o que faz sentido para o projeto.

## Resolução de Problemas

### `vault-doctor --strict` devolve código 1

É esperado quando existem warnings. O `--strict` falha com warnings por design.

### Quero eliminar warnings estritos dos adapters

Execute:

```bash
vault-doctor --fix-strict
vault-doctor --strict
```

### Skills só mostra fallback de baixa confiança

Execute:

```bash
vault-skills suggest --json
```

Confirme se os manifestos existem e têm dependências esperadas.

### `No .ai directory found`

Corra `vault-init` na raiz do projeto primeiro.

## Suporte de SO

Alvo atual:

- macOS: suportado

Outros SO podem funcionar parcialmente, mas não são alvo oficial.

## Como Deixar o Repositório AI-Friendly

Use este checklist para manter os ficheiros `.ai/` e os adapters markdown no estado ideal para agentes.

Sequência recomendada:

```bash
# 1) Ver preview da otimização sem alterar nada
vault-init --optimize --dry-run --non-interactive

# 2) Aplicar estrutura gerida otimizada
vault-init --optimize --interactive

# 3) Se projeto for legado, normalizar adapters em modo estrito
vault-doctor --fix-strict

# 4) Atualizar contexto e validar tudo
vault-context refresh
vault-doctor --strict
vault-test --all
```

Para uso diário após setup:

```bash
vault-task new --mode plan
vault-task mode execute
vault-task done
```

Isto mantém:

- ficheiros canónicos de autoridade compactos e alinhados
- adapters finos e geridos
- contexto ativo limpo (sem acumular histórico)
- ciclo de vida/arquivo consistente para handoff entre agentes

## Créditos

Alguns workflows opcionais foram inspirados por:

- `jpcaparas/superpowers-laravel`
- `felipereisdev/user-stories-skill`
- `felipereisdev/code-review-skill`
