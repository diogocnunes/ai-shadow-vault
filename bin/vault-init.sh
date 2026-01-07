#!/bin/bash

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"

echo "🛡️  Initializing AI Shadow Vault for: $PROJECT_NAME"

# Create Vault structure
mkdir -p "$PROJECT_VAULT"

# Copy templates if they don't exist in the project vault
cp -n "$(dirname "$0")/../templates/AGENTS.md" "$PROJECT_VAULT/AGENTS.md"
cp -n "$(dirname "$0")/../templates/GEMINI.md" "$PROJECT_VAULT/GEMINI.md"

echo "✅ Vault directory created at: $PROJECT_VAULT"
echo "🔗 Symlinks will be handled automatically by your ZSH integration."
echo "📝 Edit your context files in the vault to start coding with AI."