#!/bin/bash

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"

echo "🛡️  Initializing AI Shadow Vault for: $PROJECT_NAME"

# 1. Create Vault structure
mkdir -p "$PROJECT_VAULT"

# 2. Copy templates if they don't exist in the project vault
# Note: Assumes script is in bin/ and templates are in ../templates/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -n "$SCRIPT_DIR/../templates/AGENTS.md" "$PROJECT_VAULT/AGENTS.md"
cp -n "$SCRIPT_DIR/../templates/GEMINI.md" "$PROJECT_VAULT/GEMINI.md"

echo "✅ Vault directory created at: $PROJECT_VAULT"

# 3. Global Git Safety Net
echo "🔒 Configuring Global Git Safety Net..."

GLOBAL_IGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_IGNORE"

# Files to exclude globally
FILES_TO_IGNORE=(".opencode-context.md" "AGENTS.md" ".opencode.json")

for file in "${FILES_TO_IGNORE[@]}"; do
    if ! grep -q "^$file$" "$GLOBAL_IGNORE"; then
        echo "$file" >> "$GLOBAL_IGNORE"
        echo "   + Added $file to $GLOBAL_IGNORE"
    fi
done

# Force Git to use the global ignore file
git config --global core.excludesfile "$GLOBAL_IGNORE"

echo "✅ Global Git Safety Net active. Context files will never be committed."
echo "📝 Edit your context files in the vault to start coding with AI."