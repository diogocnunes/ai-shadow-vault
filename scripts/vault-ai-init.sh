#!/bin/bash

# AI Shadow Vault - Expansion Initializer
# This script initializes the .ai/ structure for enhanced context management.

VAULT_ROOT="$HOME/.gemini-vault"
PROJECT_NAME=$(basename "$PWD")
PROJECT_VAULT="$VAULT_ROOT/$PROJECT_NAME"
AI_VAULT="$PROJECT_VAULT/.ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

echo "🛡️  Initializing AI Shadow Vault Expansion for: $PROJECT_NAME"

# 1. Create Vault structure
echo "📁 Creating Vault structure at $AI_VAULT..."
mkdir -p "$AI_VAULT/plans"
mkdir -p "$AI_VAULT/docs"
mkdir -p "$AI_VAULT/context/archive"
mkdir -p "$AI_VAULT/prompts"
mkdir -p "$AI_VAULT/cache"
mkdir -p "$AI_VAULT/agents"

# 2. Install base templates
echo "📄 Installing base templates..."
cp -n "$TEMPLATES_DIR/rules.md" "$AI_VAULT/rules.md"
cp -n "$TEMPLATES_DIR/session-template.md" "$AI_VAULT/session-template.md"

# 2.1 Install agents
echo "🤖 Installing AI agents..."
cp -n "$TEMPLATES_DIR/agents/"*.sh "$AI_VAULT/agents/"
chmod +x "$AI_VAULT/agents/"*.sh

# 3. Create local symlink
if [ -L ".ai" ]; then
    echo "ℹ️  Symlink .ai already exists."
elif [ -d ".ai" ]; then
    echo "⚠️  Directory .ai already exists and is not a symlink. Skipping symlink creation."
else
    echo "🔗 Creating local symlink .ai -> $AI_VAULT..."
    ln -s "$AI_VAULT" ".ai"
fi

# 4. Claude Code Integration
echo "🤖 Setting up Claude Code integration..."
mkdir -p .claude
if [ -f ".claude/project-rules.md" ]; then
    echo "ℹ️  .claude/project-rules.md already exists."
else
    cp "$TEMPLATES_DIR/CLAUDE_PROJECT_RULES.md" ".claude/project-rules.md"
    echo "✅ Created .claude/project-rules.md"
fi

# 5. Local Git Ignore
echo "🙈 Updating local .gitignore..."
LOCAL_IGNORE=".gitignore"
touch "$LOCAL_IGNORE"

for file in "${FILES_TO_IGNORE[@]}"; do
    if ! grep -q "$file" "$LOCAL_IGNORE"; then
        echo "$file" >> "$LOCAL_IGNORE"
        echo "➕ Added $file to $LOCAL_IGNORE"
    fi
done

# 6. Global Git Safety Net
echo "🔒 Updating Global Git Safety Net..."
GLOBAL_IGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_IGNORE"

FILES_TO_IGNORE=(".ai/" ".ai" ".claude/" ".claude")

for file in "${FILES_TO_IGNORE[@]}"; do
    if ! grep -q "$file" "$GLOBAL_IGNORE"; then
        echo "**/$file" >> "$GLOBAL_IGNORE"
        echo "➕ Added $file to $GLOBAL_IGNORE"
    fi
done

git config --global core.excludesfile "$GLOBAL_IGNORE"

echo ""
echo "✨ AI Shadow Vault Expansion initialized successfully!"
echo "📍 Vault: $AI_VAULT"
echo "🔗 Local Link: .ai/"
echo "🤖 Claude Rules: .claude/project-rules.md"
echo ""
echo "Ready to code with deep context! 🚀"
