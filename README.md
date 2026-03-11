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

If you need to re-run the interactive configuration:

```bash
vault-init --force-config
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

- `vault-init`
- `vault-update`
- `vault-ai-context`
- `vault-ai-save`
- `vault-ai-resume`
- `vault-ai-stats`
- `vault-check`
- `cc`
- `vault-ext`

Optional workflow commands:

- `vault-review`
- `vault-user-stories`
- `vault-breakdown`
- `vault-skills`

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
