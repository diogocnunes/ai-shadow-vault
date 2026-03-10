# AI Shadow Vault 2.0

## Summary

AI Shadow Vault 2.0 is the first agent-agnostic release of the project.

This version introduces:

- stable repository-based vault resolution
- the new `~/.ai-shadow-vault-data` user data root
- safe migration from the legacy `~/.gemini-vault`
- a universal skills layer for multiple agents
- a generated portable context file for prompt-based tools
- standardized project files with backup-aware upgrade flows

## Highlights

### Stable Project Identity

Project vaults are no longer resolved only from `basename "$PWD"`.

Resolution now prefers:

1. `git remote.origin.url`
2. `git rev-parse --git-common-dir`
3. `git rev-parse --show-toplevel`
4. `basename "$PWD"`

This keeps context stable across:

- normal Git repositories
- Git worktrees
- temporary clones such as Polyscope environments
- non-Git folders

### New Data Root

The default user data root is now:

```bash
~/.ai-shadow-vault-data
```

Legacy installs using:

```bash
~/.gemini-vault
```

are migrated safely when possible.

Migration rules:

- if only `~/.gemini-vault` exists, it is renamed to `~/.ai-shadow-vault-data`
- if both exist, the new root becomes primary
- legacy content remains readable for compatibility

### Universal Skills Layer

Skills now work through a hybrid delivery model:

- `Gemini` and `Codex`: native global skills
- `Claude`, `Junie`, and `Opencode`: local aggregated bundle
- `Cursor`, `Windsurf`, and `Copilot`: regenerated local rule files

New commands include:

```bash
vault-skills list
vault-skills presets
vault-skills status
vault-skills activate --preset laravel-nova
vault-skills sync native context editors
vault-skills standardize
```

### Promptable Context Artifact

Projects now generate:

```text
.ai/context/agent-context.md
```

This file is meant for tools that do not support clipboard-centric flows and can be referenced directly in prompts.

### Safer Standardization

Older project files can be normalized with:

```bash
vault-skills standardize
```

Managed files are rewritten to the new format with backups stored under:

```text
.ai/backups/skills-standardization/
```

## Updating to 2.0

Recommended flow for existing users:

```bash
cd ~/Sites/my-project
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

One-time upgrade path from `1.x` to `2.x`:

```bash
cd ~/Sites/my-project
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context
```

This is required once because the old `1.x` updater only pulls the repository. The automatic project refresh behavior starts after the `2.x` code is already installed.

Important:

- updating the package with `vault-update` only needs to happen once
- the project migration steps must be run once for each existing project you want to bring to the new standard

Example:

```bash
cd ~/Sites/project-a
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context

cd ~/Sites/project-b
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context
```

When run inside a project, `vault-update` now:

- updates the installed package
- refreshes the project vault in non-interactive mode
- standardizes managed files
- re-syncs stored skill targets
- regenerates `.ai/context/agent-context.md`

If run outside a project, it updates only the package itself.

## macOS Support

AI Shadow Vault 2.0 should currently be treated as `macOS-only`.

Supported:

- `macOS`

Not supported:

- `Linux`
- `Windows`

## Recommended First Commands

For a fresh project:

```bash
vault-init
vault-ai-init
vault-skills activate --preset laravel-nova
vault-skills sync native context editors
```

For an older project:

```bash
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
vault-skills status
```
