# AI Shadow Vault

AI Shadow Vault is a portable, agent-agnostic context system for software projects.
It keeps AI guidance organized, compact, and consistent across tools like Claude Code, Codex, Gemini, Opencode, and similar agents.

## Table of Contents

- [What Is AI Shadow Vault](#what-is-ai-shadow-vault)
- [What It Is For](#what-it-is-for)
- [Why Use It](#why-use-it)
- [Who It Is For](#who-it-is-for)
- [How It Works (Mental Model)](#how-it-works-mental-model)
- [Core Principles](#core-principles)
- [Canonical Authority Order](#canonical-authority-order)
- [Vault Structure](#vault-structure)
- [Installation](#installation)
- [Initialize a Project](#initialize-a-project)
- [Detailed `vault-init` Flags](#detailed-vault-init-flags)
- [Update Flow](#update-flow)
- [Command Reference (Detailed)](#command-reference-detailed)
- [How to Use the Main Workflows](#how-to-use-the-main-workflows)
- [Skills and Auto-Detection](#skills-and-auto-detection)
- [Optional Extensions](#optional-extensions)
- [Troubleshooting](#troubleshooting)
- [OS Support](#os-support)
- [Credits](#credits)

## What Is AI Shadow Vault

AI Shadow Vault is a local context layer that:

- keeps AI context outside your main repo history
- links lightweight adapter files into your project (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, etc.)
- maintains canonical context files under `.ai/`
- helps agents load the same authority model with minimal duplication

## What It Is For

Use it to:

- standardize instructions across different AI agents
- avoid conflicting rules spread across many files
- keep active context short and usable
- preserve task continuity without turning context into long logs
- migrate legacy context layouts safely

## Why Use It

Main advantages:

- single authority model
- compact, AI-friendly active context
- optional tools remain optional (with fallback behavior)
- safer regeneration via managed-file markers
- built-in doctoring and validation (`vault-doctor`, `vault-test`)

## Who It Is For

AI Shadow Vault is designed for:

- developers using AI agents daily in real projects
- teams needing consistent AI guidance across tools
- projects that want safe defaults plus optional AI-first optimization

## How It Works (Mental Model)

Think of AI Shadow Vault as two layers:

1. `Project adapters` (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, editor rule files)
These are thin entry points that tell each agent where the canonical context lives.

2. `Canonical context` (inside `.ai/`)
This is where real authority lives: rules, current task, plans, project facts, working state, and archive.

Typical loop:

- initialize once with `vault-init`
- create or update current task with `vault-task`
- refresh generated working-state context with `vault-context refresh`
- validate drift with `vault-doctor`
- archive and reset task when done (`vault-task done` / `vault-ai-save`)

## Core Principles

- Agent-agnostic: no single vendor lock-in
- Tool-agnostic: RTK/Gemini CLI/Context7 and similar are optional
- Compact context: active files are not historical logs
- Managed vs user-authored safety: managed files can be regenerated safely
- Explicit over implicit behavior

## Canonical Authority Order

Agents should follow this exact order:

1. `.ai/rules.md`
2. `.ai/context/current-task.md`
3. `.ai/plans/`
4. `.ai/context/project-context.md`
5. `.ai/context/agent-context.md`
6. `.ai/skills/ACTIVE_SKILLS.md`
7. `.ai/docs/`
8. `.ai/archive/` (manual lookup only)

## Vault Structure

Key paths:

- `.ai/rules.md`: canonical policy
- `.ai/context/current-task.md`: single active task only
- `.ai/context/project-context.md`: stable project facts
- `.ai/context/agent-context.md`: compact working-state continuity (no history)
- `.ai/plans/`: active plans
- `.ai/docs/`: supporting docs
- `.ai/skills/ACTIVE_SKILLS.md`: active skills index
- `.ai/archive/`: historical material

Task lifecycle:

- `current-task.md` holds one active task only
- on completion, task material should be archived
- active files must not accumulate historical logs

## Installation

Clone and prepare base data dir:

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data
```

Add shell integration to `~/.zshrc`:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Reload shell:

```bash
source ~/.zshrc
```

## Initialize a Project

Safe default setup:

```bash
cd ~/Sites/my-project
vault-init
```

AI-first optimize mode (detect -> preview -> apply):

```bash
vault-init --optimize
```

Preview only (no write):

```bash
vault-init --optimize --dry-run --non-interactive
```

Interactive optimize flow:

```bash
vault-init --optimize --interactive
```

Compatibility alias:

```bash
vault-init --force-config
```

## Detailed `vault-init` Flags

This section explains exactly what each commonly used option does.

### `--optimize`

Purpose:

- enables optimization mode (`detect -> preview -> apply`)
- runs stack detection and skills confidence decisions
- shows an optimization plan before applying changes

Use when:

- you want AI-first setup quality
- you are migrating an older vault layout to vNext structure

### `--interactive`

Purpose:

- enables interactive prompts where needed
- allows confirmation before apply in optimize flow

Use when:

- you want to review/confirm decisions manually
- detection confidence is good but you still want control

### `--non-interactive`

Purpose:

- suppresses prompts and uses default behavior
- useful in scripts, CI, and deterministic runs

Use when:

- automation is preferred
- you need reproducible bootstrap without questions

### `--dry-run`

Purpose:

- works with `--optimize`
- prints plan only, without changing files

Use when:

- you want trust/preview before mutation
- you are auditing impact on an existing project

### `--yes`

Purpose:

- auto-accepts yes/no prompts
- useful for unattended flows

Use when:

- you already reviewed plan output and want apply without prompt stops

### `--force-config`

Purpose:

- compatibility alias for older workflows
- treated as: `vault-init --optimize --interactive`

Use when:

- legacy docs/scripts still call `--force-config`

Notes:

- supported for backward compatibility
- prefer `--optimize --interactive` in new usage

### Additional compatibility flags

- `--use-gemini` / `--no-use-gemini`: compatibility no-ops; optional tool behavior is controlled by rules
- `--enable-workflow` / `--disable-workflow`: compatibility path for older adapter-injection behavior
- `--herd`: passes Herd preference into configurator

## Update Flow

Update package and refresh current project:

```bash
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

`vault-update` refreshes project state with:

- `vault-init --non-interactive`
- `vault-ai-context`
- enabled extension post-update hooks

## Command Reference (Detailed)

This section explains each command, what it does, and when to use it.

### `vault-init`

What it does:

- initializes adapters and local `.ai/` workspace
- generates/refreshes managed canonical files
- can run optimize flow with confidence preview

When to use:

- first-time setup
- migration from legacy structure
- safe regeneration of managed context files

Common examples:

```bash
vault-init
vault-init --optimize --dry-run
vault-init --optimize --interactive
```

### `vault-update`

What it does:

- updates local AI Shadow Vault installation
- refreshes current project state after update

When to use:

- when pulling latest vault changes

### `vault-doctor`

What it does:

- audits structure, markers, context inflation, task mode, and capabilities hygiene

When to use:

- daily sanity check
- before/after migrations
- before handing repository state to team or CI

Options:

- `--fix`: apply safe automatic fixes
- `--fix-strict`: apply safe fixes plus force-migrate legacy adapters to thin managed templates (with backup)
- `--interactive`: review fix actions one by one
- `--strict`: fail on warnings
- `--json`: machine-readable output
- `--check <name>`: run only selected checks
- `--explain <code>`: explain a specific doctor code (e.g. `D003`)

Check names accepted by `--check`:

- `structure`
- `migration`
- `managed-markers`
- `inflation`
- `duplication`
- `capabilities`
- `task-mode`

Examples:

```bash
vault-doctor
vault-doctor --fix
vault-doctor --fix-strict
vault-doctor --interactive
vault-doctor --strict
vault-doctor --check inflation --fix
vault-doctor --explain D030
```

### `vault-test`

What it does:

- runs validation suites for vault behavior

When to use:

- before publishing changes
- in CI

Options:

- default: quick (`core` + `doctor`)
- `--all`: full (`core`, `optimize`, `task`, `migration`, `doctor`)
- `--suite <name>`: run one suite (`quick|core|optimize|task|doctor|skills|migration|all`)
- `--json`: machine-readable result

Examples:

```bash
vault-test
vault-test --all
vault-test --suite migration
vault-test --json
```

### `vault-context`

Subcommands:

- `refresh`: rebuild `.ai/context/agent-context.md`
- `trim`: run inflation-focused doctor fix

When to use:

- after editing task/plans/skills
- before asking an agent to continue work

Examples:

```bash
vault-context refresh
vault-context trim
```

### `vault-task`

Subcommands:

- `new [--mode plan|execute]`
- `quick "<goal>" [--mode plan|execute]`
- `show`
- `mode [plan|execute]`
- `done`
- `clear`
- `archive`

What each does:

- `new`: interactive wizard that asks Goal, Context, Constraints, Success Criteria, and optional Private Deliverables
- `quick`: fast non-interactive task creation (automation-friendly)
- `show`: prints current task
- `mode`: reads or changes task mode (`plan` / `execute`)
- `done`: archives current task + runs save flow
- `clear`: resets task file to template
- `archive`: same archive behavior as `done`

After `new` and `quick`, `vault-task` automatically runs:

- `vault-context refresh`
- `vault-doctor --fix`

Examples:

```bash
vault-task new --mode plan
vault-task show
vault-task mode execute
vault-task done

# Automation-friendly variant
vault-task quick "Implement OAuth login" --mode plan
```

### `vault-ai-context`

What it does:

- regenerates compact working-state summary in `.ai/context/agent-context.md`

When to use:

- after significant changes in task, plans, or skills

### `vault-ai-save`

What it does:

- archives current task (if active)
- archives completed plans
- resets `current-task.md`
- refreshes `agent-context.md`
- rebuilds docs index

When to use:

- end of a task
- context checkpoint before switching focus

### `vault-ai-resume`

What it does:

- prints current task focus, working state summary, and recent archive entries

When to use:

- beginning of session
- after interruption/context switch

### `vault-ai-stats`

What it does:

- prints vault storage stats and estimated token impact

When to use:

- monitor context growth
- spot potential inflation early

### `vault-skills`

Subcommands:

- `status`
- `suggest` (`--json`, `--plan`)
- `auto`
- `set <skill...>`
- `sync`
- `explain <skill-id>`
- `legacy ...`

What each does:

- `suggest`: detect stack and produce confidence-based decisions
- `auto`: enable only high-confidence skills
- `set`: explicitly set active skills
- `sync`: sync active skills to target surfaces
- `explain`: show why a skill exists and impact of ignoring it

Examples:

```bash
vault-skills suggest
vault-skills suggest --json
vault-skills auto
vault-skills explain qa-automation
```

### `vault-ext`

Subcommands:

- `list`
- `info <extension>`
- `status`
- `enable <extension...>`
- `disable <extension...>`
- `sync [extension...]`
- `run-hook <hook>`

Use when:

- enabling optional workflows per project

### `vault-review` and aliases

Commands:

- `vault-review`
- `vault-code-review` (alias)
- `vault-pr-review` (alias)

Scopes:

- `--scope working`
- `--scope staged`
- `--scope branch --base <branch>`
- `--scope commit --commit <sha>`
- `--scope range --from <sha> --to <sha>`

What it does:

- prepares structured review prompt and output path under `.ai/reviews/`

### `vault-user-stories` and alias

Commands:

- `vault-user-stories "<goal>"`
- `vault-breakdown` (alias)

What it does:

- prepares planning prompt for user stories and target file under `.ai/plans/`

## How to Use the Main Workflows

This section explains the exact examples and why each command exists.

### 1) Start/refresh context

Commands:

```bash
vault-context refresh
vault-task show
```

What happens:

- `vault-context refresh` regenerates `agent-context.md` based on current branch, task, plans, and skills
- `vault-task show` prints the active task so you can confirm current goal/mode before starting work

When to use:

- start of day
- before handing context to an AI agent
- after pulling changes from teammates

### 2) Run a new task

Commands:

```bash
vault-task new --mode plan
# ... planning work
vault-task mode execute
# ... implementation work
vault-task done
```

Step-by-step meaning:

- `new --mode plan`: opens the wizard and creates a complete task document in planning mode
- `mode execute`: flips task from planning to execution once plan is ready
- `done`: archives task artifacts and resets active task context safely

When to use:

- for every meaningful feature/bug task
- whenever you want clean task lifecycle and no history accumulation in active files

### 3) Daily health checks

Commands:

```bash
vault-doctor
vault-test
```

What happens:

- `vault-doctor`: checks project vault health
- `vault-test`: checks vault command behavior

When to use:

- before committing vault changes
- after migration or optimize apply

### 4) Strict migration cleanup

Commands:

```bash
vault-doctor --fix-strict
vault-doctor --strict
```

What happens:

- `--fix-strict` force-migrates legacy long adapters to thin managed templates and stores backup
- `--strict` confirms the project has no warnings

When to use:

- one-time migration cleanup
- standardization across team repos

## Skills and Auto-Detection

`vault-skills suggest` detects stack signals from manifests such as:

- `composer.json`
- `package.json`
- `pyproject.toml`
- `requirements.txt`
- `go.mod`

Decision model:

- `>= 0.80`: auto-enabled candidates
- `>= 0.50 and < 0.80`: suggested-only candidates

Use `vault-skills explain <skill-id>` for transparent rationale.

## Optional Extensions

Extensions are optional and project-scoped.

Built-in groups include:

- `planning`
- `review`
- `skills`
- `laravel-stack` (reserved)

Enable only what your project needs.

## Troubleshooting

### `vault-doctor --strict` returns code 1

Expected when warnings exist. `--strict` fails on warnings by design.

### I want strict warnings gone for adapters

Run:

```bash
vault-doctor --fix-strict
vault-doctor --strict
```

### Skills fallback shows only low-confidence suggestion

Run:

```bash
vault-skills suggest --json
```

Check whether manifests exist and contain expected dependencies.

### `No .ai directory found`

Run `vault-init` in project root first.

## OS Support

Current target:

- macOS: supported

Other OSes may work partially but are not official targets.

## Make Repository AI-Friendly

Use this checklist to keep `.ai/` files and adapter markdowns in ideal shape for agents.

Recommended sequence:

```bash
# 1) Preview optimization safely
vault-init --optimize --dry-run --non-interactive

# 2) Apply optimized managed structure
vault-init --optimize --interactive

# 3) Run strict adapter migration if needed (legacy projects)
vault-doctor --fix-strict

# 4) Refresh working-state context and validate everything
vault-context refresh
vault-doctor --strict
vault-test --all
```

For daily operation after setup:

```bash
vault-task new --mode plan
vault-task mode execute
vault-task done
```

This keeps:

- canonical authority files compact and aligned
- adapter files thin and managed
- active task context clean (no history accumulation)
- archive/lifecycle behavior consistent for agent handoffs

## Credits

Some optional workflows were inspired by:

- `jpcaparas/superpowers-laravel`
- `felipereisdev/user-stories-skill`
- `felipereisdev/code-review-skill`
