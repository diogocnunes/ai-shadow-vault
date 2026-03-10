# AI Shadow Vault

AI Shadow Vault is a local context layer for AI-assisted development. It keeps project-specific AI instructions, plans, history, and skills outside the main repository while still making them available inside the project when needed.

## What It Solves

AI Shadow Vault helps when you want to:

- keep AI context out of Git
- reuse local plans and session history across tools
- support multiple agents with one shared project context
- avoid breaking context when working in Git worktrees or temporary clones

## Core Pieces

The system is built from three layers:

- a user data root for vault files
- a local `.ai/` workspace inside each project
- generated files and symlinks for specific agents

## Data Root

The default data root is:

```bash
~/.ai-shadow-vault-data
```

Legacy installs may still use:

```bash
~/.gemini-vault
```

Migration behavior:

- if `~/.gemini-vault` exists and `~/.ai-shadow-vault-data` does not, it is renamed automatically
- if both exist, `~/.ai-shadow-vault-data` is primary
- legacy content can still be read for compatibility

## Stable Project Resolution

Project identity is resolved in this order:

1. `git remote.origin.url`
2. `git rev-parse --git-common-dir`
3. `git rev-parse --show-toplevel`
4. `basename "$PWD"`

This keeps the vault stable across:

- normal repositories
- Git worktrees
- temporary clones created by tools such as Polyscope
- non-Git directories

## Installation

1. Clone the project:

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
mkdir -p ~/.ai-shadow-vault-data
```

2. Add this to `~/.zshrc`:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

3. Reload the shell.

If you only need to reload AI Shadow Vault later, prefer:

```bash
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

Do not repeatedly run `source ~/.zshrc` just to refresh AI Shadow Vault.

4. Inside a project:

```bash
vault-init
vault-ai-init
```

## Updating an Existing Install

If you already have AI Shadow Vault installed, the recommended update flow is:

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

This one-time sequence is necessary because the old `1.x` `vault-update` only performs the package pull. The automatic post-update refresh starts working from `2.x` onward.

Important:

- `vault-update` itself only needs to update the package once
- the `vault-init --non-interactive`, `vault-skills standardize`, `vault-skills sync`, and `vault-ai-context` steps must be run once for each project you want to migrate

Example with two existing projects:

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

When `vault-update` is executed inside a project, it now does more than `git pull`. It will also:

- refresh the project vault in non-interactive mode
- standardize managed AI files to the current format
- re-sync stored skill targets
- regenerate `.ai/context/agent-context.md`

If you run `vault-update` outside a project, it only updates the package itself.

If you want to run the project refresh steps manually, use:

```bash
vault-init --non-interactive
vault-skills standardize
vault-skills sync
vault-ai-context
```

## OS Compatibility

Current support:

- `macOS`: supported
- `Linux`: not supported
- `Windows`: not supported

Why:

- shell integration depends on `zsh`
- most scripts are written for `bash`
- clipboard support expects `pbcopy` on macOS or `xclip` on Linux
- some generation code still uses macOS-style `sed -i ''`
- Polyscope integration is macOS-only

At this point, the package should be treated as macOS-only.

## Local `.ai/` Workspace

The local `.ai/` directory is the project-side context layer.

Important paths:

| Path | Purpose |
| :--- | :--- |
| `.ai/rules.md` | project rules |
| `.ai/plans/` | implementation plans |
| `.ai/docs/` | local documentation |
| `.ai/context/archive/` | archived sessions |
| `.ai/context/agent-context.md` | portable promptable context |
| `.ai/skills/ACTIVE_SKILLS.md` | active skills bundle |

## Main Commands

| Command | Purpose |
| :--- | :--- |
| `vault-init` | initialize the project vault and symlinks |
| `vault-ai-init` | initialize the local `.ai/` workspace |
| `vault-ai-resume` | show the latest archived session and active plans |
| `vault-ai-save` | archive the current session |
| `vault-ai-context` | generate `.ai/context/agent-context.md` |
| `vault-ai-stats` | show local cache metrics |
| `vault-check` | verify vault integrity |
| `cc` | quick Claude-oriented context flow |
| `vault-skills` | manage universal skills |

## Quick Start Examples

### Example 1: Basic project setup

```bash
cd ~/Sites/my-project
vault-init
vault-ai-init
```

### Example 2: Start a task with a plan

```bash
.ai/agents/plan-creator.sh "Refactor billing flow"
vault-ai-context
```

### Example 3: Prepare Claude context

```bash
cc
```

### Example 4: Activate skills for a Laravel Nova project

```bash
vault-skills activate --preset laravel-nova
vault-skills sync native context editors
vault-skills status
```

### Example 5: Update an older installation

```bash
cd ~/Sites/my-project
vault-update
source ~/.ai-shadow-vault/scripts/shell_integration.zsh
```

## Portable Context File

For tools that do not use clipboard workflows, use:

```text
.ai/context/agent-context.md
```

Typical prompt example:

```text
Use .ai/context/agent-context.md as the current project summary.
Then follow .ai/plans/refactor-billing-flow.md.
```

## Universal Skills Layer

AI Shadow Vault uses a hybrid skills model:

- `Gemini` and `Codex`: native global skills
- `Claude`, `Junie`, and `Opencode`: project-local aggregate bundle
- `Cursor`, `Windsurf`, and `Copilot`: regenerated local rules

Useful commands:

```bash
vault-skills status
vault-skills presets
vault-skills list
vault-skills activate --preset laravel-nova
vault-skills activate --preset filament syncfusion-document-editor
vault-skills sync native context editors
vault-skills standardize
```

State files:

- `.ai/skills/active-skills.txt`
- `.ai/skills/active-skills.json`
- `.ai/skills/ACTIVE_SKILLS.md`

## Typical Workflows

### Claude workflow

```bash
cc
.ai/agents/plan-creator.sh "Add audit trail"
claude
vault-ai-save
```

### Gemini workflow

```bash
vault-ai-context
.ai/agents/plan-creator.sh "Validate architecture"
vault-skills activate --preset laravel-nova
vault-skills sync gemini
```

### Upgrade an older project

```bash
vault-skills standardize
```

This creates backups before rewriting managed files into the new standard format.

## Troubleshooting

### `cc` does not copy anything

- On macOS, make sure `pbcopy` is available
- On Linux, install `xclip`
- Even without clipboard support, `cc` still regenerates `.ai/context/agent-context.md`

### Skills look duplicated or old files are messy

Run:

```bash
vault-skills standardize
```

This backs up managed files and rewrites them to the current format.

### A tool cannot use clipboard-based context

Use:

```text
.ai/context/agent-context.md
```

and, when needed:

```text
.ai/skills/ACTIVE_SKILLS.md
```

### Linux and Windows

They are not supported targets for this package at the moment.

## Git Safety

Generated and sensitive files are kept out of normal repository flow using:

- `.git/info/exclude`
- `~/.gitignore_global`

This includes `.ai/`, `.claude/`, local symlinks, and generated artifacts such as `agent-context.md`.

## Related Guides

- [README_PT.md](./README_PT.md)
- [AI_CACHE_GUIDE.md](./AI_CACHE_GUIDE.md)
- [SUPERPOWERS_GUIDE.md](./SUPERPOWERS_GUIDE.md)
- [CLAUDE_WORKFLOW_FAQ.md](./CLAUDE_WORKFLOW_FAQ.md)
- [GEMINI_WORKFLOW_GUIDE.md](./GEMINI_WORKFLOW_GUIDE.md)
