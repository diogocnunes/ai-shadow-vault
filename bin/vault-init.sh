#!/bin/bash

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"

echo "🛡️  Initializing AI Shadow Vault for: $PROJECT_NAME"

# 1. Create Vault structure
mkdir -p "$PROJECT_VAULT"

# 2. Copy templates if they don't exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -n "$SCRIPT_DIR/../templates/AGENTS.md" "$PROJECT_VAULT/AGENTS.md"
cp -n "$SCRIPT_DIR/../templates/GEMINI.md" "$PROJECT_VAULT/GEMINI.md"
# Novo: Suporte ao Copilot
cp -n "$SCRIPT_DIR/../templates/copilot-instructions.md" "$PROJECT_VAULT/copilot-instructions.md"

echo "✅ Vault directory created at: $PROJECT_VAULT"

# 3. Global Git Safety Net
echo "🔒 Configuring Global Git Safety Net..."
GLOBAL_IGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_IGNORE"

# Adicionado copilot-instructions.md à lista de ignorados
FILES_TO_IGNORE=("GEMINI.md" ".opencode-context.md" "AGENTS.md" ".opencode.json" "copilot-instructions.md")

for file in "${FILES_TO_IGNORE[@]}"; do
    if ! grep -q "$file" "$GLOBAL_IGNORE"; then
        echo "**/$file" >> "$GLOBAL_IGNORE"
    fi
done

git config --global core.excludesfile "$GLOBAL_IGNORE"
echo "✅ Global Git Safety Net updated."