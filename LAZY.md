# Quick Start (Lazy Mode)

> This is the shortest path to get started.

## 1. Install

> zsh only (macOS default). For bash, add the source line to `~/.bashrc` instead.

```bash
git clone https://github.com/diogocnunes/ai-shadow-vault.git ~/.ai-shadow-vault
echo 'source ~/.ai-shadow-vault/scripts/shell_integration.zsh' >> ~/.zshrc
source ~/.zshrc
```

## 2. Update

```bash
vault-update
source ~/.zshrc
```

## 3. First time in a project

```bash
cd my-project
vault-init  # sets up AI context and project files
```

## 4. After updating / syncing changes

**Update the vault itself:**

```bash
vault-update
source ~/.zshrc
```

**Reapply managed files in a project** (e.g. CLAUDE.md, configs):

```bash
cd my-project
vault-init
```

## 5. Daily usage

```bash
vault-ai-context    # refresh context before starting work
vault-ai-resume     # recap what you were working on
vault-ai-save       # archive completed work
vault-doctor        # check everything is healthy
```
