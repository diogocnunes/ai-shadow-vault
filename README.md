# AI Shadow Vault

AI Shadow Vault is a local AI context layer for development. It keeps project context outside the repository, links the right files back into the project, and generates a portable `.ai/context/agent-context.md` summary for agents.

## Product Shape

AI Shadow Vault now has two layers:

- `core`: vault resolution, local `.ai/` workspace, symlinks, session/history files, and generated context
- `extensions`: optional workflows such as review prompts, planning prompts, and skills syncing

The default install is intentionally small. Optional workflows must be enabled per project.

## What Stays in Core

- stable project and worktree resolution
- external vault storage under `~/.ai-shadow-vault-data`
- local `.ai/` workspace bootstrap
- `GEMINI.md`, `CLAUDE.md`, `AGENTS.md`, editor rule linking
- session save/resume flows
- generated `.ai/context/agent-context.md`
- shell integration and health checks

## Optional Extensions

List available extensions:

```bash
vault-ext list
```

Enable an extension inside a project:

```bash
vault-ext enable planning
vault-ext enable review
vault-ext enable skills
```

Current built-in extension groups:

- `planning`: user-story breakdown workflow
- `review`: code review prompt preparation
- `skills`: universal skills activation and sync
- `laravel-stack`: reserved for Laravel-specific optional workflows

Catalogued external packages:

- `superpowers-laravel`: upstream Laravel superpowers package
- `user-stories-skill`: upstream user-story planning package
- `code-review-skill`: upstream review package

Inspect an extension:

```bash
vault-ext info superpowers-laravel
vault-ext info user-stories-skill
vault-ext info code-review-skill
```

Legacy commands such as `vault-review`, `vault-user-stories`, and `vault-skills` still work, but they are now treated as optional workflows rather than core behavior.

## Installation

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data
```

Add this to `~/.zshrc`:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Reload the shell, then initialize a project:

```bash
cd ~/Sites/my-project
vault-init
```

If you use Gemini CLI for large-codebase analysis, opt in to the managed section:

```bash
vault-init --use-gemini
```

If you need to re-run the interactive configuration:

```bash
vault-init --force-config
```

Disable the managed Gemini section later if needed:

```bash
vault-init --no-use-gemini
```

## Update Flow

Update the package:

```bash
cd ~/Sites/my-project
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

`vault-update` now refreshes only the core project state:

- reruns `vault-init --non-interactive`
- regenerates `.ai/context/agent-context.md`
- runs hooks for already-enabled extensions

It no longer auto-runs optional workflow setup by default.

## Main Commands

Core:

| Command | What it does | When to use it |
| :--- | :--- | :--- |
| `vault-init` | Bootstraps vault files, local `.ai/` workspace, symlinks, and base context/configuration. Supports optional managed sections such as `--use-gemini` / `--no-use-gemini`. | First-time project setup or when re-initializing vault-managed files. |
| `vault-update` | Updates AI Shadow Vault package, then refreshes current project via `vault-init --non-interactive`, `vault-ai-context`, and extension hooks. | Pulling latest tool updates and refreshing project context. |
| `vault-ai-context` | Regenerates `.ai/context/agent-context.md` with session, plans, extensions, docs, and rules summary. | Before handing work to agents or after relevant context changes. |
| `vault-ai-save` | Archives current `.ai/session.md`, moves completed plans from `.ai/plans` to `.ai/context/archive/plans`, rebuilds `.ai/docs/INDEX.md`, and shows vault stats. | End of session or checkpointing context. |
| `vault-ai-resume` | Shows latest archived session recap plus active plans and available docs. | Start of a new session to recover project state quickly. |
| `vault-ai-stats` | Prints vault storage stats (docs/cache/plans counts and estimated token savings). | Quick health/size check of local AI workspace. |
| `vault-check` | Runs health checks against vault-linked instruction/context files. | Verifying vault links and required files are present. |
| `vault-debug-sections` | Audits managed markers, RTK lifecycle consistency, and cross-root skill conflicts; supports safe auto-fixes with `--fix` and forced conflict pruning with `--fix --force-conflicts` (keeps highest-precedence copy). | Diagnosing marker drift, broken sections, and skills duplication issues. |
| `cc` | Runs `claude-start` (refreshes context, prints recap, copies `.ai/rules.md` when clipboard tools exist). | Starting a Claude session with current vault context. |
| `vault-ext` | Lists, enables/disables, inspects, syncs, and runs hooks for optional extensions. | Managing optional workflows per project. |

Optional workflow commands:

| Command | What it does | When to use it |
| :--- | :--- | :--- |
| `vault-review` | Builds a scope-based review prompt from Git diff targets and writes intended review output path under `.ai/reviews/`. | Preparing structured code-review prompts for agents. |
| `vault-user-stories` | Builds a planning prompt from a goal and targets `.ai/plans/<slug>.user-stories.md`. | Breaking down a feature goal into actionable user stories. |
| `vault-breakdown` | Alias wrapper for `vault-user-stories`. | Same use case as `vault-user-stories`, with shorter naming. |
| `vault-skills` | Activates/syncs optional skill bundles and updates target instruction surfaces. | Managing optional skills overlays for supported tools/editors. |

## Quick Start

Basic setup:

```bash
cd ~/Sites/my-project
vault-init
vault-ai-context
```

Enable planning workflow:

```bash
vault-ext enable planning
vault-user-stories "Implement OAuth login"
```

Enable review workflow:

```bash
vault-ext enable review
vault-review --scope staged
```

Enable skills workflow:

```bash
vault-ext enable skills
vault-skills activate --preset reviewing
vault-skills sync native context editors
```

Debug managed sections and lifecycle drift:

```bash
vault-debug-sections
vault-debug-sections --fix
vault-debug-sections --fix --force-conflicts
```

## Local Workspace

Important paths:

| Path | Purpose |
| :--- | :--- |
| `.ai/rules.md` | project rules |
| `.ai/plans/` | local plans |
| `.ai/docs/` | local documentation |
| `.ai/context/archive/` | archived sessions |
| `.ai/context/agent-context.md` | generated summary for agents |
| `.ai/extensions/enabled.txt` | enabled optional extensions |
| `.ai/skills/ACTIVE_SKILLS.md` | optional skills bundle, when used |

## OS Support

Current support:

- `macOS`: supported
- `Linux`: not supported
- `Windows`: not supported

This package should still be treated as macOS-first for now.

## Migration Notes

If you are coming from `1.x` or an earlier `2.x` build that assumed batteries-included behavior:

1. Run `vault-update`
2. Run `vault-init --non-interactive`
3. Re-enable only the workflows you still want with `vault-ext enable ...`
4. Regenerate context with `vault-ai-context`

Examples:

```bash
vault-ext enable planning review
vault-ext enable skills
```

## Credits

Some optional workflows were inspired by or adapted from:

- `jpcaparas/superpowers-laravel`
- `felipereisdev/user-stories-skill`
- `felipereisdev/code-review-skill`
