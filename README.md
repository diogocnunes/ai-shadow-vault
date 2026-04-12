# AI Shadow Vault

AI Shadow Vault is a shell-first tool that keeps AI adapter files outside Git and links them into each project.

It stays intentionally small:
- generated adapters live in an external vault
- project workspaces only link `.ai/docs` and `.ai/plans`
- Git excludes are managed locally and idempotently
- there is no memory engine, skills system, archive, or task runtime

## Install

Homebrew is the primary installation path.

```bash
brew tap <your-tap>
brew install ai-vault
ai-vault
```

If you are developing from source:

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

If no global config exists, AI Shadow Vault starts a short setup wizard and stores config in:

```text
$XDG_CONFIG_HOME/ai-shadow-vault/config.json
```

Fallback:

```text
~/.config/ai-shadow-vault/config.json
```

The wizard collects only:
- vault base path
- enabled adapters
- RTK instructions toggle

Suggested base path defaults to:

```text
~/.ai-shadow-vault-data
```

If synced folders are available, they are offered as optional choices.

## Main CLI

```bash
ai-vault install
ai-vault init
ai-vault update
```

### `ai-vault install`

Runs the setup wizard or reconfigures the existing global config.

### `ai-vault init`

Links the current project into the configured external vault.

It:
- resolves a stable vault identity shared across Git worktrees
- uses the configured vault base path
- generates only the selected adapters
- links `.ai/docs` and `.ai/plans`
- repairs symlinks and migrations with confirmation
- updates `.git/info/exclude` idempotently

### `ai-vault update`

Behavior depends on install mode:
- Homebrew install: tells you to run `brew upgrade ai-vault`
- source/git install: updates the checkout from `origin/main`
- packaged non-git install: tells you to reinstall the latest release

## External Vault Layout

Each project resolves to:

```text
<vault_base_path>/<project-slug>-<hash>/
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  docs/
  plans/
```

Inside the project:

```text
.ai/
  docs -> external/docs
  plans -> external/plans

AGENTS.md -> external/AGENTS.md
CLAUDE.md -> external/CLAUDE.md
GEMINI.md -> external/GEMINI.md
```

Only the adapters selected in global config are generated and linked.

## Project Identity

Vault identity is stable across Git worktrees.

Identity root:
- Git repository: repository common root
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

All adapters are generated from one shared internal instruction model.

Detected repo facts can influence output:
- Pest in `composer.json`
- Playwright in `package.json`
- Laravel in `composer.json`
- RTK availability via `command -v rtk`

RTK instructions are included only when:
- RTK is available now
- the global config enables the RTK extra

## Git Excludes

AI Shadow Vault manages only `.git/info/exclude`.

Managed block:

```text
# >>> ai-shadow-vault >>>
/.ai/
/CLAUDE.md
/AGENTS.md
/GEMINI.md
# <<< ai-shadow-vault <<<
```

The block is generated from the currently enabled adapters. `.gitignore` is never modified.

## Migration and Repair

For `.ai/docs` and `.ai/plans`:
- real directories are treated as user-authored content
- migration requires confirmation
- name conflicts are preserved using:

```text
name.migrated-YYYYMMDD-HHMMSS.ext
```

For adapter files in the project root:
- missing symlink: create
- correct symlink: no-op
- wrong symlink: repair with confirmation
- real file: show diff and require confirmation before replacement

## Idempotency

Repeated `ai-vault init` runs are designed to be idempotent:
- no duplicate symlinks
- no duplicate exclude entries
- no unnecessary rewrites
- no changes when the project is already correct

## Synced Folders

You can point the vault base path at a synced location such as:
- Google Drive
- Dropbox
- another local cloud-mounted directory

That choice is machine-level config, not project config.

## Compatibility Commands

These still work as compatibility wrappers:

```bash
vault-init
vault-update
```

They forward internally to the new CLI and print a short note. They are kept to avoid breaking existing users immediately.

## Packaging

The repository includes:
- thin public entrypoints in `bin/`
- runtime logic under `libexec/ai-vault/`
- a Homebrew formula in `Formula/ai-vault.rb`
- a release helper in `release/build-homebrew-tarball.sh`
