# AI Shadow Vault

AI Shadow Vault is a local developer-experience infrastructure for AI-assisted coding.

It keeps AI context outside your Git repository and injects only the runtime files each project needs.

## What This Package Is

AI Shadow Vault is a ZSH-based local system that standardizes:

- project rules and guardrails
- task and context files
- agent memory/session flow
- optional stack-specific skills through packs

It is not a cloud service, not a hosted agent, and not a framework plugin.

## Why It Exists

Most teams hit the same problems when using AI tools in real projects:

- context files pollute Git history
- private notes leak into repositories
- each project ends up with inconsistent AI conventions
- prompts drift and quality drops over time

AI Shadow Vault solves this by separating infrastructure (core) from stack expertise (packs).

## Who It Is For

- developers using Claude/Codex/Gemini in daily coding workflows
- teams that want repeatable AI project setup
- maintainers who need strict local control over context and privacy

## Vision and Values

AI Shadow Vault is built around four values:

1. Privacy by default: local-first context, no mandatory cloud dependency.
2. Predictability over magic: explicit files, explicit commands, explicit contracts.
3. Maintainability at scale: core stays generic; stack intelligence lives in packs.
4. Low-friction adoption: works with existing repositories without forcing rewrites.

## What Changed in v5 (Hard Cut)

From `v5.0.0` onward, core no longer provides moved skills through legacy fallback.

If a skill was moved to the Laravel pack, core now returns:

- `ASV-HARD-MIGRATION-001`

This hard cut was intentional to:

- remove the misleading “Laravel-first core” perception
- make the core genuinely stack-agnostic
- enforce one source of truth for Laravel skills (`ai-shadow-vault-laravel`)

## Installation

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data

# Add to ~/.zshrc
source ~/.ai-shadow-vault/scripts/shell_integration.zsh

# Reload shell
source ~/.zshrc
```

## Update

```bash
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

## Quick Start (New Project)

```bash
cd /path/to/project
vault-init
vault-ai-context
vault-doctor
```

## Enable Skills (Pack-first)

```bash
cd /path/to/project
vault-ext enable laravel
vault-ext enable skills
vault-skills set backend-expert
vault-skills sync
```

Useful checks:

```bash
cat .ai/extensions/lock.json
cat .ai/skills/ACTIVE_SKILLS.md
```

## Daily Workflow

```bash
# Refresh context
vault-ai-context

# Work on a task
vault-task "Implement feature X"

# Validate health
vault-doctor --strict
```

## Normalize Projects from <= 4.x to 5.x

Use this for existing projects that were on legacy/fallback behavior.

### Step 1: Update core to v5

```bash
cd ~/.ai-shadow-vault
git fetch --tags
git checkout v5.0.0
source ~/.zshrc
```

### Step 2: Re-initialize project state

```bash
cd /path/to/project
vault-init --non-interactive
```

### Step 3: Enable required pack + skills workflow

```bash
vault-ext enable laravel
vault-ext enable skills
```

### Step 4: Re-apply active skills

```bash
# Example
vault-skills set backend-expert
vault-skills sync
```

### Step 5: Validate final state

```bash
vault-ai-context
vault-doctor --strict
```

If you get `ASV-HARD-MIGRATION-001`, install/enable the required pack and re-run `vault-skills set ...`.

## Command Guide (What Each One Does)

### `vault-init`

Initializes or normalizes `.ai` structure and managed links/files for the current project.

Main options:
- `--optimize`: runs optimize flow (detect -> plan -> apply)
- `--interactive`: enables prompts/confirmations
- `--non-interactive`: default safe automation mode
- `--dry-run`: preview mode for optimize flow
- `--yes`: auto-accept prompts
- `--force-config`: compatibility alias (deprecated) for `--optimize --interactive`
- `--herd`: compatibility flag forwarded to configurator
- `--use-gemini` / `--no-use-gemini`: compatibility flags (tooling remains optional)
- `--enable-workflow` / `--disable-workflow`: compatibility flags (deprecated behavior notice)

### `vault-update`

Updates local installation (`~/.ai-shadow-vault`) from `origin/main` and refreshes the current project.

What it runs after update (or when already up-to-date):
- `vault-init --non-interactive`
- `vault-ai-context`
- `vault-ext run-hook post-update`

### `vault-ai-context`

Regenerates `.ai/context/agent-context.md` with compact working-state continuity:
- current focus
- active branch
- active plans
- blockers/risks
- active skills

### `vault-task`

Creates/manages `.ai/context/current-task.md` in canonical format.

Subcommands:
- `new [--mode plan|execute]`: interactive task creation
- `quick "<goal>" [--mode plan|execute]`: fast task seed from one line
- `compile [--stdin|--input "<text>"|--file <path>] [--mode plan|execute] [--output-lang en|pt|auto] [--enrich conservative|repo-aware] [--format markdown|json] [--apply]`: compiles free text into structured task
- `show`: prints current task file
- `mode [plan|execute]`: get/set current mode frontmatter
- `done`: archives state via `vault-ai-save`
- `clear`: resets task to template
- `archive`: same archival behavior as `done`

### `vault-doctor`

Health check and normalization command for `.ai` structure/rules/contracts.

Main options:
- `--fix`: apply safe automatic fixes
- `--fix-strict`: apply strict fixes (implies `--fix`)
- `--strict`: fail on warnings/errors for stricter CI-like checks
- `--json`: machine-readable output
- `--interactive`: guided fix flow (cannot be combined with `--json` or `--fix*`)
- `--check <name>`: run specific checks only (can repeat)
- `--explain <code>`: explain a diagnostic code (example: `D003`)

### `vault-ext`

Project extension/pack manager.

Subcommands:
- `list`: show available extensions
- `info <extension>`: show metadata/source/kind
- `status`: show enabled extensions in current project
- `enable <extension...>`: enable extension(s); installs official packs when needed
- `disable <extension...>`: disable extension(s)
- `sync [extension...]`: re-run sync hooks and refresh lockfile
- `run-hook <hook>`: run a hook across enabled extensions

### `vault-skills`

Skills workflow command (pack-first in v5).

Main subcommands:
- `status`: show active/available skills status
- `suggest [--json|--plan]`: detect/suggest skills and pack hints
- `auto`: auto-enable high-confidence suggestions
- `set <skill...>`: set active skills
- `sync`: rebuild/sync generated active-skills artifacts
- `explain <skill-id>`: short explanation of skill purpose
- `legacy ...`: pass-through to legacy installer interface

### `vault-pack validate <pack-dir>`

Validates `pack.json` manifest schema for an external pack directory.

### `vault-ai-save`

Archives current task/plans into `.ai/archive`, resets active task, refreshes agent context, and updates docs index.

### `vault-ai-resume`

Prints a quick recap of current task, working-state context, and recent archive entries.

### `vault-ai-stats`

Shows local vault statistics (size, docs/cache/plans/archive counts, estimated token footprint).

### `cc` and `cx` (Shell aliases)

Available after loading shell integration:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

- `cc`: runs Claude bootstrap recap (`claude-start`)
- `cx`: runs Codex bootstrap recap (`codex-start`)

## Packs and Contract

Packs are external repositories (for example, `ai-shadow-vault-laravel`) with a minimal `pack.json` contract.

Required manifest fields:

- `name`
- `version`
- `description`
- `core_api`
- `capabilities`

Reference:

- `docs/pack-contract.md`

## Troubleshooting

### `ASV-COMPAT-001`

Pack `core_api` range is not compatible with your core version.
Use a compatible pack release or update core.

### `ASV-HARD-MIGRATION-001`

Requested skill is no longer provided by core.
Enable the required pack (usually `laravel`) and set the skill again.

### `No .ai directory found`

Run `vault-init` in the target project first.

## OS Support

- macOS
- Linux (ZSH)

## Summary

AI Shadow Vault is the stable local foundation.
Packs provide stack depth.

Core is infrastructure.
Packs are expertise.
