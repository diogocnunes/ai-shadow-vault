# AI Shadow Vault

Keep AI adapter files out of Git.

AI Shadow Vault is a shell-first tool for teams and solo developers who want `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` available inside each project without turning those files into repo noise.

It gives you:
- a clean `ai-vault` CLI
- a branded first-run installer
- adapters stored outside the repository
- stable project identity across Git worktrees
- linked `.ai/docs` and `.ai/plans` folders
- local Git exclusions managed without touching `.gitignore`

It does not try to be a memory engine, task system, skills runtime, or agent framework.

## Preview

![AI Shadow Vault installer](assets/images/carbon.png)

## Why It Exists

Most teams want AI instructions close to the code, but not committed into every repository.

AI Shadow Vault solves that by storing adapter files in a machine-level vault and linking them into each project only when needed.

That means:
- your repo stays clean
- your adapters stay reusable
- your setup stays deterministic
- your worktrees share the same vault identity

## Install

Homebrew is the primary install path.

```bash
brew tap <your-tap>
brew install ai-vault
ai-vault
```

If you are running from source during development:

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
echo 'source ~/.ai-shadow-vault/scripts/shell_integration.zsh' >> ~/.zshrc
source ~/.zshrc
ai-vault
```

## First Run

Run:

```bash
ai-vault
```

On first run, AI Shadow Vault opens a short interactive setup that lets you choose:
- vault base path
- default adapters
- RTK instructions toggle

Global config is stored at:

```text
$XDG_CONFIG_HOME/ai-shadow-vault/config.json
```

Fallback:

```text
~/.config/ai-shadow-vault/config.json
```

Suggested default vault path:

```text
~/.ai-shadow-vault-data
```

If synced folders are detected, they are offered as install choices too.

## Main Commands

```bash
ai-vault install
ai-vault init
ai-vault update
```

### `ai-vault install`

Runs the setup wizard or updates the existing machine-level config.

### `ai-vault init`

Links the current project to the configured vault.

It will:
- resolve the project root
- derive a stable identity shared across Git worktrees
- generate the selected adapters
- link `.ai/docs` and `.ai/plans`
- repair symlinks when needed
- migrate user-authored `.ai/docs` or `.ai/plans` directories with confirmation
- update `.git/info/exclude` idempotently

### `ai-vault update`

Update behavior depends on how the tool was installed:
- Homebrew install: tells you to run `brew upgrade ai-vault`
- source/git install: updates the checkout from `origin/main`
- packaged non-git install: tells you to reinstall the latest release

## What Gets Created

External vault layout:

```text
<vault_base_path>/<project-slug>-<hash>/
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  docs/
  plans/
```

Project layout:

```text
.ai/
  docs -> external/docs
  plans -> external/plans

AGENTS.md -> external/AGENTS.md
CLAUDE.md -> external/CLAUDE.md
GEMINI.md -> external/GEMINI.md
```

Only the adapters enabled in global config are generated and linked.

## Stable Project Identity

Vault paths are intentionally stable across Git worktrees.

Identity root:
- Git project: repository common root
- non-Git project: `realpath(project root)`

Hash:
- `sha1(realpath(identity-root))`
- first 8 hex characters

Final format:

```text
<slug>-<hash>
```

## Adapter Generation

Supported adapters:
- `CLAUDE.md`
- `AGENTS.md`
- `GEMINI.md`

All adapters are rendered from one shared internal instruction model so they stay aligned instead of drifting apart.

Repo facts can influence the generated output:
- Pest in `composer.json`
- Playwright in `package.json`
- Laravel in `composer.json`
- RTK availability via `command -v rtk`

RTK instructions are included only when:
- RTK is available now
- the global config enables RTK instructions

## Git Strategy

AI Shadow Vault manages only `.git/info/exclude`.

Managed block example:

```text
# >>> ai-shadow-vault >>>
/.ai/
/CLAUDE.md
/AGENTS.md
/GEMINI.md
# <<< ai-shadow-vault <<<
```

The block is generated from the adapters currently enabled in config.

`.gitignore` is never modified.

## Migration and Repair Rules

For `.ai/docs` and `.ai/plans`:
- real directories are treated as user content
- migration requires confirmation
- file conflicts are preserved using:

```text
name.migrated-YYYYMMDD-HHMMSS.ext
```

For adapter files in the project root:
- missing symlink: create it
- correct symlink: no-op
- wrong symlink: offer repair
- real file: show a diff and require confirmation before replacement

If an adapter is disabled later in config, `ai-vault init` detects the old symlink, shows it as a removal action, and updates `.git/info/exclude` accordingly.

## Idempotent by Design

Repeated `ai-vault init` runs should produce no changes when the project is already in the desired state.

That includes:
- no duplicate symlinks
- no duplicate exclude entries
- no unnecessary rewrites
- no repeated migration work

## Synced Vaults

The vault base path can live in:
- Google Drive
- Dropbox
- another synced folder
- any local directory you choose

That choice is machine-level configuration, not project configuration.

## Compatibility Commands

These still work:

```bash
vault-init
vault-update
```

They forward to the new CLI and print a short compatibility note.

## Homebrew and Packaging

The repository includes:
- thin public entrypoints in `bin/`
- runtime logic in `libexec/ai-vault/`
- a Homebrew formula in `Formula/ai-vault.rb`
- a release helper in `release/build-homebrew-tarball.sh`

The intended user experience is:

```bash
brew install ai-vault
ai-vault
```

## Philosophy

AI Shadow Vault is deliberately narrow in scope.

It is:
- a linker
- a generator
- a machine-level adapter manager

It is not:
- project memory
- agent orchestration
- workflow automation
- a hidden runtime

Keep the adapters. Keep the context. Keep Git clean.
